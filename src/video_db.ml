open! Core
open! Async
open! Import
module Caqti_type = Db_type
open Caqti_type.Std
open Caqti_request.Infix

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
  let get_user_version = (unit ->! int) "PRAGMA user_version"

  let set_user_version n =
    (unit ->. unit) ~oneshot:true (sprintf "PRAGMA user_version = %d" n)
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

  let vacuum = (unit ->. unit) "VACUUM"

  let migrations =
    [| V1.all; V2.all; V3.all |]
    |> Array.map ~f:(List.map ~f:((unit ->. unit) ~oneshot:true))
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
  Conn.exec ((unit ->. unit) ~oneshot:true sql) () |> convert_error
;;

let find_and_check ((module Conn) : t) type_ test ?here ?message ?equal ~expect sql =
  let%bind actual = Conn.find ((unit ->! type_) ~oneshot:true sql) () |> convert_error in
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
      string
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
  let%bind () =
    if Result.is_ok result then exec_oneshot db "PRAGMA optimize" else return ()
  in
  let%bind () = Conn.disconnect () |> Deferred.ok in
  Deferred.return result
;;

let select_count_total_videos = (unit ->! int) {|
SELECT COUNT(*) FROM videos
|}

let select_count_watched_videos =
  (unit ->! int) {|
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
  (tup2 bool video_id ->. unit) {|
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
  (tup2 string string ->. unit) sql
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
  (tup3 video_id string string ->. unit) sql
;;

let add_video_overwrite = add_video ~overwrite:true
let add_video_no_overwrite = add_video ~overwrite:false

let add_video ((module Conn) : t) (video_info : Video_info.t) ~overwrite =
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
  return ()
;;

let select_video_by_id =
  (video_id ->? tup2 video_info bool)
    {|
SELECT channel_id, channel_title, video_id, video_title, watched
FROM videos_all
WHERE video_id = ?
|}
;;

let get ((module Conn) : t) video_id =
  Conn.find_opt select_video_by_id video_id |> convert_error
;;

let mem t video_id = get t video_id >>| Option.is_some

let mark_watched ((module Conn) : t) video_id state =
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
(* TODO: Optimize this query by only adding WHERE clauses for columns present in the
   filter. *)
let get_random_video =
  (Filter.t ->? video_id)
    {|
SELECT video_id FROM videos_all
WHERE ($1 IS NULL OR channel_id = $1)
  AND ($2 IS NULL OR channel_title LIKE $2 ESCAPE '\')
  AND ($3 IS NULL OR video_id = $3)
  AND ($4 IS NULL OR video_title LIKE $4 ESCAPE '\')
  AND ($5 IS NULL OR watched IS TRUE = $5 IS TRUE)
ORDER BY RANDOM()
LIMIT 1
|}
;;

let get_random_video ((module Conn) : t) filter =
  match%bind Conn.find_opt get_random_video filter |> convert_error with
  | Some video_id -> return video_id
  | None -> Deferred.Or_error.error_s [%message "No unwatched videos matching filter"]
;;

let get_videos =
  (Filter.t ->* tup2 video_info bool)
    {|
SELECT channel_id, channel_title, video_id, video_title, watched FROM videos_all
WHERE ($1 IS NULL OR channel_id = $1)
  AND ($2 IS NULL OR channel_title LIKE $2 ESCAPE '\')
  AND ($3 IS NULL OR video_id = $3)
  AND ($4 IS NULL OR video_title LIKE $4 ESCAPE '\')
  AND ($5 IS NULL OR watched IS TRUE = $5 IS TRUE)
|}
;;

let get_videos ((module Conn) : t) filter =
  Pipe.create_reader ~close_on_exception:false (fun writer ->
    Conn.iter_s get_videos (fun elt -> Pipe.write writer elt |> Deferred.ok) filter
    |> convert_error
    |> Deferred.Or_error.ok_exn)
;;

let remove_video = (video_id ->. unit) {|
DELETE FROM videos WHERE id = ?
|}

let strict_remove ((module Conn) : t) video_id =
  let%map rows_affected =
    Conn.exec_with_affected_count remove_video video_id |> convert_error
  in
  if rows_affected = 1 then `Ok else `Missing
;;
