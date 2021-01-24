open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

module Filter = struct
  type t =
    { channel_id : string option
    ; channel_title : string option
    ; video_id : string option
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
    and channel_id = flag "channel-id" (optional string) ~doc:"ID channel ID"
    and channel_title = flag "channel-title" (optional string) ~doc:"TITLE channel TITLE"
    and video_id = flag "video-id" (optional string) ~doc:"ID video ID"
    and video_title = flag "video-title" (optional string) ~doc:"TITLE video TITLE" in
    { channel_id; channel_title; video_id; video_title }
  ;;

  let t : t Caqti_type.t =
    Caqti_type.custom
      Caqti_type.(tup4 (option string) (option string) (option string) (option string))
      ~encode:(fun { channel_id; channel_title; video_id; video_title } ->
        Ok (channel_id, channel_title, video_id, video_title))
      ~decode:(fun (channel_id, channel_title, video_id, video_title) ->
        Ok { channel_id; channel_title; video_id; video_title })
  ;;
end

type t = Caqti_async.connection

(* TODO: Sprinkling convert_error everywhere might not be necessary if we define an
   appropriate error monad with all of the possibilities. *)
let convert_error =
  Deferred.Result.map_error ~f:(fun e -> e |> Caqti_error.show |> Error.of_string)
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

  let migrations =
    [| [ create_videos_table ] |]
    |> Array.map ~f:(List.map ~f:(Caqti_request.exec ~oneshot:true Caqti_type.unit))
  ;;

  let desired_user_version = Array.length migrations

  let ensure_up_to_date (module Conn : Caqti_async.CONNECTION) =
    let%bind user_version = Conn.find get_user_version () |> convert_error in
    Deferred.Or_error.repeat_until_finished user_version (fun user_version ->
      match Ordering.of_int (Int.compare user_version desired_user_version) with
      | Equal -> return (`Finished ())
      | Greater ->
        Deferred.Or_error.error_s
          [%message
            "Database user version exceeds expected version"
              (user_version : int)
              (desired_user_version : int)]
      | Less ->
        (* [user_version] is equal to the next set of migration statements to apply *)
        let stmts = migrations.(user_version) in
        let%bind () = Conn.start () |> convert_error in
        (match%bind.Deferred
           Deferred.Or_error.List.iter stmts ~f:(fun stmt ->
             Conn.exec stmt () |> convert_error)
         with
         | Error e1 as result ->
           (match%map.Deferred Conn.rollback () |> convert_error with
            | Ok () -> result
            | Error e2 -> Error (Error.of_list [ e1; e2 ]))
         | Ok () ->
           let%bind () =
             Conn.exec (set_user_version (user_version + 1)) () |> convert_error
           in
           let%bind () = Conn.commit () |> convert_error in
           return (`Repeat (user_version + 1))))
  ;;
end

(* Set busy timeout to 10ms.  This query uses [find] because it returns the new busy
   timeout. *)
let set_busy_timeout =
  Caqti_request.find
    ~oneshot:true
    Caqti_type.unit
    Caqti_type.int
    "PRAGMA busy_timeout = 10"
;;

let optimize = Caqti_request.exec ~oneshot:true Caqti_type.unit "PRAGMA optimize"

let with_file dbpath ~f =
  let uri = Uri.make ~scheme:"sqlite3" ~path:dbpath () in
  let%bind db = Caqti_async.connect uri |> convert_error in
  let (module Conn) = db in
  let%bind () =
    Conn.find set_busy_timeout () |> convert_error |> Deferred.Or_error.ignore_m
  in
  let%bind () = Migrate.ensure_up_to_date db in
  Monitor.protect
    (fun () -> f db)
    ~finally:(fun () ->
      let%bind.Deferred result = Conn.exec optimize () |> convert_error in
      let%bind.Deferred () = Conn.disconnect () in
      Deferred.return (ok_exn result))
;;

let wrap_core_error = Deferred.Result.map_error ~f:(fun e -> `Error e)

let unwrap_core_error =
  Deferred.Result.map_error ~f:(function
    | `Error e -> e
    | #Caqti_error.t as e -> e |> Caqti_error.show |> Error.of_string)
;;

let unwrap_core_error_and_unsupported ~name =
  Deferred.Result.map_error ~f:(function
    | `Error e -> e
    | `Unsupported -> Error.createf "Unsupported operation: %s" name
    | #Caqti_error.t as e -> e |> Caqti_error.show |> Error.of_string)
;;

let select_non_watched_videos =
  Caqti_request.collect
    Caqti_type.unit
    Video_info.t
    {|
SELECT channel_id, channel_title, video_id, video_title
FROM videos
WHERE NOT watched
|}
;;

let iter_non_watched_videos (module Conn : Caqti_async.CONNECTION) ~f =
  Conn.iter_s
    select_non_watched_videos
    (fun video_info -> f video_info |> wrap_core_error)
    ()
  |> unwrap_core_error
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

let video_stats (module Conn : Caqti_async.CONNECTION) =
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
    Caqti_type.(tup2 bool Video_id.t)
    {|
UPDATE videos SET watched = ?
WHERE video_id = ?
|}
;;

let add_video ~conflict_resolution =
  let sql =
    sprintf
      {|
INSERT OR %s INTO videos
(channel_id, channel_title, video_id, video_title)
VALUES (?, ?, ?, ?)
|}
      conflict_resolution
  in
  Caqti_request.exec Video_info.t sql
;;

let add_video_overwrite = add_video ~conflict_resolution:"REPLACE"
let add_video_no_overwrite = add_video ~conflict_resolution:"IGNORE"

let add_video
      (module Conn : Caqti_async.CONNECTION)
      video_info
      ~mark_watched:should_mark_watched
      ~overwrite
  =
  let request = if overwrite then add_video_overwrite else add_video_no_overwrite in
  let%bind () = Conn.exec request video_info |> convert_error in
  match should_mark_watched with
  | None -> return ()
  | Some state ->
    let watched =
      match state with
      | `Watched -> true
      | `Unwatched -> false
    in
    let%bind rows_affected =
      Conn.call mark_watched (watched, video_info.video_id) ~f:(fun response ->
        let%bind.Deferred.Result () = Conn.Response.exec response in
        Conn.Response.affected_count response)
      |> unwrap_core_error_and_unsupported ~name:"affected_count"
    in
    if rows_affected <> 1
    then
      Deferred.Or_error.error_s
        [%message "Failed to mark watched" ~video_id:(video_info.video_id : Video_id.t)]
    else return ()
;;

let select_video_by_id =
  Caqti_request.find_opt
    Video_id.t
    Caqti_type.(tup2 Video_info.t bool)
    {|
SELECT channel_id, channel_title, video_id, video_title, watched
FROM videos
WHERE video_id = ?
|}
;;

let get (module Conn : Caqti_async.CONNECTION) video_id =
  Conn.find_opt select_video_by_id video_id |> convert_error
;;

let mem (module Conn : Caqti_async.CONNECTION) video_id =
  Conn.find_opt select_video_by_id video_id |> convert_error >>| Option.is_some
;;

let mark_watched (module Conn : Caqti_async.CONNECTION) video_id state =
  (* TODO: Deduplicate this code *)
  let watched =
    match state with
    | `Watched -> true
    | `Unwatched -> false
  in
  match%bind
    Conn.call mark_watched (watched, video_id) ~f:(fun response ->
      let%bind.Deferred.Result () = Conn.Response.exec response in
      Conn.Response.affected_count response)
    |> unwrap_core_error_and_unsupported ~name:"affected_count"
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
    Video_info.t
    {|
SELECT channel_id, channel_title, video_id, video_title FROM videos
WHERE NOT watched
  AND ($1 IS NULL OR channel_id = $1)
  AND ($2 IS NULL OR channel_title GLOB $2)
  AND ($3 IS NULL OR video_id = $3)
  AND ($4 IS NULL OR video_title GLOB $4)
ORDER BY RANDOM()
LIMIT 1
|}
;;

let get_random_unwatched_video (module Conn : Caqti_async.CONNECTION) filter =
  let%map video = Conn.find_opt get_random_unwatched_video filter |> convert_error in
  Option.value_exn video ~message:"No unwatched videos matching filter"
;;

let get_videos =
  Caqti_request.collect
    Caqti_type.(tup2 (option bool) Filter.t)
    Caqti_type.(tup2 Video_info.t bool)
    {|
SELECT channel_id, channel_title, video_id, video_title, watched FROM videos
WHERE ($1 IS NULL OR watched IS TRUE = $1 IS TRUE)
  AND ($2 IS NULL OR channel_id = $2)
  AND ($3 IS NULL OR channel_title GLOB $3)
  AND ($4 IS NULL OR video_id = $4)
  AND ($5 IS NULL OR video_title GLOB $5)
|}
;;

let get_videos (module Conn : Caqti_async.CONNECTION) filter ~watched =
  Conn.collect_list get_videos (watched, filter) |> convert_error
;;
