open! Core
open! Async
open! Import

module Caqti_type = struct
  include Caqti_type

  let stringable (type a) (module M : Stringable with type t = a) : a t =
    let open M in
    custom
      string
      ~encode:(fun t -> Ok (to_string t))
      ~decode:(fun s ->
        Or_error.try_with (fun () -> of_string s)
        |> Result.map_error ~f:Error.to_string_hum)
  ;;

  let video_id = stringable (module Video_id)

  module Fields = struct
    type 'a caqti_type = 'a t

    (* Difference list encoding of serialization functions for each field.

       [fields_rest] represents the fields that have not yet been folded over. *)
    type ('fields, 'fields_rest, 'a) t_ =
      { unwrap : 'fields -> 'fields_rest
      ; encode : ('a -> 'fields_rest) -> 'a -> 'fields
      ; caqti_type : 'fields_rest caqti_type -> 'fields caqti_type
      }

    type ('fields, 'a) t = ('fields, unit, 'a) t_

    let of_make_creator
          (type a fields)
          ((decode : fields -> a), ({ unwrap = _; encode; caqti_type } : (fields, a) t))
      : a caqti_type
      =
      let encode = encode (Fn.const ()) in
      let caqti_type = caqti_type unit in
      custom caqti_type ~encode:(fun x -> Ok (encode x)) ~decode:(fun x -> Ok (decode x))
    ;;

    let init (type fields) : (fields, fields, _) t_ =
      { unwrap = Fn.id; encode = Fn.id; caqti_type = Fn.id }
    ;;

    let folder
          (type fields fields_rest a this_field)
          (type_ : this_field caqti_type)
          (field : (a, this_field) Fieldslib.Field.t)
          ({ unwrap; encode; caqti_type } : (fields, this_field * fields_rest, a) t_)
      : (fields -> this_field) * (fields, fields_rest, a) t_
      =
      let encode encode_rest =
        encode (fun record -> Fieldslib.Field.get field record, encode_rest record)
      in
      let caqti_type rest = caqti_type (tup2 type_ rest) in
      fst << unwrap, { unwrap = snd << unwrap; encode; caqti_type }
    ;;
  end

  let video_info =
    Youtube_api.Video_info.Fields.make_creator
      Fields.init
      ~channel_id:(Fields.folder string)
      ~channel_title:(Fields.folder string)
      ~video_id:(Fields.folder video_id)
      ~video_title:(Fields.folder string)
    |> Fields.of_make_creator
  ;;

  module Std = struct
    include Std

    let video_id = video_id
    let _video_info = video_info
  end
end

module Filter = struct
  type t =
    { channel_id : string option
    ; channel_title : string option
    ; video_id : Video_id.t option
    ; video_title : string option
    }
  [@@deriving fields]

  let is_empty =
    let is_none _ _ = Option.is_none in
    Fields.Direct.for_all
      ~channel_id:is_none
      ~channel_title:is_none
      ~video_id:is_none
      ~video_title:is_none
  ;;

  let param =
    let%map_open.Command () = return ()
    and channel_id = flag "-channel-id" (optional string) ~doc:"ID channel ID"
    and channel_title = flag "-channel-title" (optional string) ~doc:"TITLE channel TITLE"
    and video_id =
      flag "-video-id" (optional Video_id.Plain_or_in_url.arg_type) ~doc:"ID video ID"
    and video_title = flag "-video-title" (optional string) ~doc:"TITLE video TITLE" in
    { channel_id; channel_title; video_id; video_title }
  ;;

  let t : t Caqti_type.t =
    let open Caqti_type.Std in
    let f = Caqti_type.Fields.folder in
    Fields.make_creator
      Caqti_type.Fields.init
      ~channel_id:(f (option string))
      ~channel_title:(f (option string))
      ~video_id:(f (option video_id))
      ~video_title:(f (option string))
    |> Caqti_type.Fields.of_make_creator
  ;;
end

type t = Caqti_async.connection

(* TODO: Sprinkling convert_error everywhere might not be necessary if we define an
   appropriate error monad with all of the possibilities. *)
let convert_error =
  Deferred.Result.map_error ~f:(fun e -> e |> Caqti_error.show |> Error.of_string)
;;

let with_txn ((module Conn) : t) ~f =
  let%bind () = Conn.start () |> convert_error in
  match%bind.Deferred Monitor.try_with_join_or_error ~name:"with_txn" ~here:[%here] f with
  | Ok x ->
    let%bind () = Conn.commit () |> convert_error in
    return x
  | Error error as result ->
    (match%map.Deferred Conn.rollback () |> convert_error with
     | Ok () -> result
     | Error rollback_error -> Error (Error.of_list [ error; rollback_error ]))
;;

module Migrate = struct
  let get_user_version =
    Caqti_request.find Caqti_type.unit Caqti_type.int "PRAGMA user_version"
  ;;

  let set_user_version n =
    Caqti_request.exec
      ~oneshot:true
      Caqti_type.unit
      (sprintf "PRAGMA user_version = %d" n)
  ;;

  let disable_foreign_keys = "PRAGMA foreign_keys = OFF"
  let enable_foreign_keys = "PRAGMA foreign_keys = ON"

  module V1 = struct
    let create_videos_table =
      {|
CREATE TABLE videos(
  video_id      TEXT PRIMARY KEY,
  video_title   TEXT,
  channel_id    TEXT,
  channel_title TEXT,
  watched       INTEGER NOT NULL DEFAULT 0
)
|}
    ;;

    let all = [ create_videos_table ]
  end

  module V2 = struct
    let create_channels_table =
      {|
CREATE TABLE channels (
  id    TEXT PRIMARY KEY,
  title TEXT NOT NULL
)
|}
    ;;

    let create_new_videos_table =
      {|
CREATE TABLE videos_new (
  id         TEXT PRIMARY KEY,
  title      TEXT NOT NULL,
  channel_id TEXT NOT NULL REFERENCES channels ON DELETE CASCADE,
  watched    INTEGER NOT NULL DEFAULT 0
)
|}
    ;;

    (* Pick latest channel title for each channel ID

       According to https://sqlite.org/lang_select.html,

       When the min() or max() aggregate functions are used in an aggregate query, all
       bare columns in the result set take values from the input row which also contains
       the minimum or maximum. So in the query above, the value of the "b" column in the
       output will be the value of the "b" column in the input row that has the largest
       "c" value. There is still an ambiguity if two or more of the input rows have the
       same minimum or maximum value or if the query contains more than one min() and/or
       max() aggregate function. Only the built-in min() and max() functions work this
       way.  *)
    let populate_channels_table =
      {|
INSERT INTO channels (id, title)
SELECT channel_id, channel_title
  FROM (
    SELECT max(rowid), channel_id, channel_title
      FROM videos AS v1
     GROUP BY channel_id)
|}
    ;;

    let populate_new_videos_table =
      {|
INSERT INTO videos_new (id, title, channel_id, watched)
SELECT video_id, video_title, channel_id, watched
  FROM videos
|}
    ;;

    let drop_old_videos_table = {|
DROP TABLE videos
|}

    let rename_new_videos_table = {|
ALTER TABLE videos_new RENAME TO videos
|}

    let create_videos_index_on_channel_id =
      {|
CREATE INDEX index_videos_on_channel_id ON videos (channel_id)
|}
    ;;

    let create_trigger_to_delete_unused_channels =
      {|
CREATE TRIGGER trigger_delete_unused_channel
  AFTER DELETE ON videos
  FOR EACH ROW
    WHEN NOT EXISTS (SELECT 1 FROM videos WHERE channel_id = old.channel_id)
    BEGIN
      DELETE FROM channels WHERE id = old.channel_id;
    END
|}
    ;;

    let create_videos_all_view =
      {|
CREATE VIEW videos_all (
  video_id,
  video_title,
  channel_id,
  channel_title,
  watched
)
  AS
  SELECT videos.id, videos.title, channels.id, channels.title, videos.watched
  FROM videos JOIN channels ON videos.channel_id = channels.id
|}
    ;;

    let all =
      [ disable_foreign_keys
      ; create_channels_table
      ; create_new_videos_table
      ; populate_channels_table
      ; populate_new_videos_table
      ; drop_old_videos_table
      ; rename_new_videos_table
      ; create_videos_index_on_channel_id
      ; create_trigger_to_delete_unused_channels
      ; create_videos_all_view
      ; enable_foreign_keys
      ]
    ;;
  end

  module V3 = struct
    let create_videos_index_on_title =
      {|
CREATE INDEX index_videos_on_title ON videos (title COLLATE NOCASE)
|}
    ;;

    let create_channels_index_on_title =
      {|
CREATE INDEX index_channels_on_title ON channels (title COLLATE NOCASE)
|}
    ;;

    let all = [ create_videos_index_on_title; create_channels_index_on_title ]
  end

  let vacuum = Caqti_request.exec Caqti_type.unit "VACUUM"

  let migrations =
    [| V1.all; V2.all; V3.all |]
    |> Array.map ~f:(List.map ~f:(Caqti_request.exec ~oneshot:true Caqti_type.unit))
  ;;

  let desired_user_version = Array.length migrations

  let increase_version ((module Conn) : t) =
    let%bind () =
      with_txn
        (module Conn)
        ~f:(fun () ->
          let%bind user_version = Conn.find get_user_version () |> convert_error in
          if user_version >= desired_user_version
          then return ()
          else
            Async_interactive.Job.run
              "Migrating database version %d to %d"
              user_version
              (user_version + 1)
              ~f:(fun () ->
                (* [user_version] is equal to the next set of migration statements to apply *)
                let stmts = migrations.(user_version) in
                let%bind () =
                  Deferred.Or_error.List.iter stmts ~f:(fun stmt ->
                    Conn.exec stmt () |> convert_error)
                in
                let%bind () =
                  Conn.exec (set_user_version (user_version + 1)) () |> convert_error
                in
                return ()))
    in
    let%bind () = Conn.exec vacuum () |> convert_error in
    return ()
  ;;

  let rec ensure_up_to_date ((module Conn) as db : t) ~retries =
    let%bind user_version = Conn.find get_user_version () |> convert_error in
    match Ordering.of_int (Int.compare user_version desired_user_version) with
    | Equal -> return ()
    | Greater ->
      Deferred.Or_error.error_s
        [%message
          "Database user version exceeds expected version"
            (user_version : int)
            (desired_user_version : int)]
    | Less ->
      if retries <= 0
      then
        Deferred.Or_error.error_s
          [%message
            "Failed to upgrade database to latest version"
              (user_version : int)
              (desired_user_version : int)]
      else (
        (* We don't really care if [increase_version] fails with, say, SQLITE_BUSY, only
           that the schema was migrated. *)
        match%bind.Deferred increase_version db with
        | Ok () -> ensure_up_to_date db ~retries
        | Error err ->
          [%log.global.error
            "Failed to upgrade schema, retrying"
              (err : Error.t)
              ~retries_remaining:(retries - 1 : int)];
          ensure_up_to_date db ~retries:(retries - 1))
  ;;
end

let exec_oneshot ((module Conn) : t) sql =
  Conn.exec (Caqti_request.exec ~oneshot:true Caqti_type.unit sql) () |> convert_error
;;

let find_and_check ((module Conn) : t) type_ test ?here ?message ?equal ~expect sql =
  let%bind actual =
    Conn.find (Caqti_request.find ~oneshot:true Caqti_type.unit type_ sql) ()
    |> convert_error
  in
  test ?here ?message ?equal ~expect actual;
  return ()
;;

let setup_connection ((module Conn) as db : t) =
  (* Enable enforcement of foreign key constraints *)
  let%bind () = exec_oneshot db "PRAGMA foreign_keys = ON" in
  (* Set journal mode to write-ahead logging *)
  let%bind () =
    find_and_check
      db
      Caqti_type.string
      [%test_result: String.Caseless.t]
      ~here:[ [%here] ]
      ~expect:"WAL"
      "PRAGMA journal_mode = WAL"
  in
  let%bind () = Migrate.ensure_up_to_date db ~retries:3 in
  return ()
;;

let with_file_and_txn dbpath ~f =
  (* TODO: Once available, use [File_path] library. *)
  let%bind () =
    Monitor.try_with_or_error ~here:[%here] (fun () ->
      Unix.mkdir ~p:() (Filename.dirname dbpath))
  in
  let uri =
    Uri.make
      ~scheme:"sqlite3"
      ~path:dbpath
      ~query:[ "busy_timeout", [ Int.to_string 10_000 ] ]
      ()
  in
  let%bind db = Caqti_async.connect uri |> convert_error in
  let%bind () = setup_connection db in
  let (module Conn) = db in
  let%bind.Deferred result = with_txn (module Conn) ~f:(fun () -> f db) in
  (* FIXME: Maybe don't bother optimizing if result is an error *)
  let%bind () = exec_oneshot db "PRAGMA optimize" in
  let%bind () = Conn.disconnect () |> Deferred.ok in
  Deferred.return result
;;

let select_count_total_videos =
  Caqti_request.find Caqti_type.unit Caqti_type.int {|
SELECT COUNT(*) FROM videos
|}
;;

let select_count_watched_videos =
  Caqti_request.find
    Caqti_type.unit
    Caqti_type.int
    {|
SELECT COUNT(*) FROM videos
WHERE watched
|}
;;

let video_stats ((module Conn) : t) =
  let%bind total_videos = Conn.find select_count_total_videos () |> convert_error in
  let%bind watched_videos = Conn.find select_count_watched_videos () |> convert_error in
  return
    { Stats.total_videos
    ; watched_videos
    ; unwatched_videos = total_videos - watched_videos
    }
;;

let mark_watched =
  Caqti_request.exec
    Caqti_type.(tup2 bool video_id)
    {|
UPDATE videos SET watched = ?
WHERE id = ?
|}
;;

let add_channel ~overwrite =
  let sql =
    sprintf
      {|
INSERT %s INTO channels (id, title)
VALUES (?, ?)
%s
|}
      (if overwrite then "" else "OR IGNORE")
      (if overwrite
       then {|
ON CONFLICT (id)
DO UPDATE SET title = excluded.title
|}
       else "")
  in
  Caqti_request.exec Caqti_type.(tup2 string string) sql
;;

let add_channel_overwrite = add_channel ~overwrite:true
let add_channel_no_overwrite = add_channel ~overwrite:false

let add_video ~overwrite =
  let sql =
    sprintf
      {|
INSERT %s INTO videos
(id, title, channel_id)
VALUES (?, ?, ?)
%s
|}
      (if overwrite then "" else "OR IGNORE")
      (if overwrite
       then
         {|
ON CONFLICT (id)
DO UPDATE SET title = excluded.title,
              channel_id = excluded.channel_id
|}
       else "")
  in
  Caqti_request.exec Caqti_type.(tup3 video_id string string) sql
;;

let add_video_overwrite = add_video ~overwrite:true
let add_video_no_overwrite = add_video ~overwrite:false

let add_video
      ((module Conn) : t)
      (video_info : Youtube_api.Video_info.t)
      ~mark_watched:should_mark_watched
      ~overwrite
  =
  let%bind () =
    Conn.exec
      (if overwrite then add_channel_overwrite else add_channel_no_overwrite)
      (video_info.channel_id, video_info.channel_title)
    |> convert_error
  in
  let%bind () =
    Conn.exec
      (if overwrite then add_video_overwrite else add_video_no_overwrite)
      (video_info.video_id, video_info.video_title, video_info.channel_id)
    |> convert_error
  in
  match should_mark_watched with
  | None -> return ()
  | Some state ->
    let watched =
      match state with
      | `Watched -> true
      | `Unwatched -> false
    in
    let%bind rows_affected =
      Conn.exec_with_affected_count mark_watched (watched, video_info.video_id)
      |> convert_error
    in
    if rows_affected <> 1
    then
      Deferred.Or_error.error_s
        [%message "Failed to mark watched" ~video_id:(video_info.video_id : Video_id.t)]
    else return ()
;;

let select_video_by_id =
  Caqti_request.find_opt
    Caqti_type.video_id
    Caqti_type.(tup2 video_info bool)
    {|
SELECT channel_id, channel_title, video_id, video_title, watched
FROM videos_all
WHERE video_id = ?
|}
;;

let get ((module Conn) : t) video_id =
  Conn.find_opt select_video_by_id video_id |> convert_error
;;

let mem ((module Conn) : t) video_id =
  Conn.find_opt select_video_by_id video_id |> convert_error >>| Option.is_some
;;

let mark_watched ((module Conn) : t) video_id state =
  (* TODO: Deduplicate this code *)
  let watched =
    match state with
    | `Watched -> true
    | `Unwatched -> false
  in
  match%bind
    Conn.exec_with_affected_count mark_watched (watched, video_id) |> convert_error
  with
  | 0 ->
    Deferred.Or_error.error_s
      [%message "No rows were changed" (video_id : Video_id.t) (watched : bool)]
  | 1 -> return ()
  | changes ->
    Deferred.Or_error.error_s
      [%message "Unexpected change count" (video_id : Video_id.t) (changes : int)]
;;

(* TODO: Once Caqti supports Sqlite user functions, replace globbing with a Re-based
   regexp.

   https://github.com/paurkedal/ocaml-caqti/issues/56 *)
let get_random_unwatched_video =
  Caqti_request.find_opt
    Filter.t
    Caqti_type.video_id
    {|
SELECT video_id FROM videos_all
WHERE NOT watched
  AND ($1 IS NULL OR channel_id = $1)
  AND ($2 IS NULL OR channel_title LIKE $2 ESCAPE '\')
  AND ($3 IS NULL OR video_id = $3)
  AND ($4 IS NULL OR video_title LIKE $4 ESCAPE '\')
ORDER BY RANDOM()
LIMIT 1
|}
;;

let get_random_unwatched_video ((module Conn) : t) filter =
  match%bind Conn.find_opt get_random_unwatched_video filter |> convert_error with
  | Some video_id -> return video_id
  | None -> Deferred.Or_error.error_s [%message "No unwatched videos matching filter"]
;;

let get_videos =
  Caqti_request.collect
    Caqti_type.(tup2 (option bool) Filter.t)
    Caqti_type.(tup2 video_info bool)
    {|
SELECT channel_id, channel_title, video_id, video_title, watched FROM videos_all
WHERE ($1 IS NULL OR watched IS TRUE = $1 IS TRUE)
  AND ($2 IS NULL OR channel_id = $2)
  AND ($3 IS NULL OR channel_title LIKE $3 ESCAPE '\')
  AND ($4 IS NULL OR video_id = $4)
  AND ($5 IS NULL OR video_title LIKE $5 ESCAPE '\')
|}
;;

let get_videos ((module Conn) : t) filter ~watched =
  Pipe.create_reader ~close_on_exception:false (fun writer ->
    Conn.iter_s
      get_videos
      (fun elt -> Pipe.write writer elt |> Deferred.ok)
      (watched, filter)
    |> convert_error
    |> Deferred.Or_error.ok_exn)
;;

let remove_video =
  Caqti_request.exec Caqti_type.video_id {|
DELETE FROM videos WHERE id = ?
|}
;;

let strict_remove ((module Conn) : t) video_id =
  let%map rows_affected =
    Conn.exec_with_affected_count remove_video video_id |> convert_error
  in
  if rows_affected = 1 then `Ok else `Missing
;;
