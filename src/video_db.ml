open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax
open Db.Arity
open Db.Kind

type t =
  { db : Db.t
  ; setup_schema : (non_select * arity0) Db.Stmt.t Lazy.t
  ; select_non_watched_videos : (select * arity0) Db.Stmt.t Lazy.t
  ; select_count_total_videos : (select * arity0) Db.Stmt.t Lazy.t
  ; select_count_watched_videos : (select * arity0) Db.Stmt.t Lazy.t
  ; add_video_overwrite : (non_select * arity4) Db.Stmt.t Lazy.t
  ; add_video_no_overwrite : (non_select * arity4) Db.Stmt.t Lazy.t
  ; mark_watched : (non_select * arity2) Db.Stmt.t Lazy.t
  ; get_random_unwatched_video : (select * arity0) Db.Stmt.t Lazy.t
  }

let setup_schema db =
  Db.prepare_exn
    db
    Non_select
    Arity0
    {|
CREATE TABLE IF NOT EXISTS videos(
  video_id      TEXT PRIMARY KEY,
  video_title   TEXT,
  channel_id    TEXT,
  channel_title TEXT,
  watched       INTEGER NOT NULL DEFAULT 0
);
|}
;;

let select_non_watched_videos db =
  Db.prepare_exn
    db
    Select
    Arity0
    {|
SELECT channel_id, channel_title, video_id, video_title
FROM videos
WHERE NOT watched;
|}
;;

let select_count_total_videos db =
  Db.prepare_exn db Select Arity0 {|
SELECT COUNT(*) FROM videos;
|}
;;

let select_count_watched_videos db =
  Db.prepare_exn db Select Arity0 {|
SELECT COUNT(*) FROM videos
WHERE watched;
|}
;;

let add_video db ~conflict_resolution =
  let sql =
    sprintf
      {|
INSERT OR %s INTO videos
(video_id, video_title, channel_id, channel_title)
VALUES (?, ?, ?, ?);
|}
      conflict_resolution
  in
  Db.prepare_exn db Non_select Arity4 sql
;;

let add_video_overwrite db = add_video db ~conflict_resolution:"REPLACE"
let add_video_no_overwrite db = add_video db ~conflict_resolution:"IGNORE"

let mark_watched db =
  Db.prepare_exn
    db
    Non_select
    Arity2
    {|
UPDATE videos SET watched = ?
WHERE video_id = ?;
|}
;;

let get_random_unwatched_video db =
  Db.prepare_exn
    db
    Select
    Arity0
    {|
SELECT video_id, video_title, channel_id, channel_title FROM videos
WHERE NOT watched
ORDER BY RANDOM()
LIMIT 1;
|}
;;

let do_setup_schema t =
  let stmt = force t.setup_schema in
  Db.Stmt.run Arity0 stmt
;;

let create ?(should_setup_schema = true) db =
  let t =
    { db
    ; setup_schema = lazy (setup_schema db)
    ; select_non_watched_videos = lazy (select_non_watched_videos db)
    ; select_count_total_videos = lazy (select_count_total_videos db)
    ; select_count_watched_videos = lazy (select_count_watched_videos db)
    ; add_video_overwrite = lazy (add_video_overwrite db)
    ; add_video_no_overwrite = lazy (add_video_no_overwrite db)
    ; mark_watched = lazy (mark_watched db)
    ; get_random_unwatched_video = lazy (get_random_unwatched_video db)
    }
  in
  let%map () =
    if should_setup_schema
    then do_setup_schema t >>| (ignore : int -> unit)
    else return ()
  in
  t
;;

let open_file ?should_setup_schema dbpath =
  let%bind db = Db.open_file dbpath in
  create ?should_setup_schema db
;;

let with_file ?should_setup_schema dbpath ~f =
  Db.with_file dbpath ~f:(fun db ->
    let%bind t = create ?should_setup_schema db in
    f t)
;;

let close t = Db.close t.db

let string_exn (data : Sqlite3.Data.t) =
  match data with
  | TEXT x | BLOB x -> x
  | data -> failwithf !"expected TEXT or BLOB, got: %{Sqlite3.Data#debug}" data ()
;;

let int64_exn (data : Sqlite3.Data.t) =
  match data with
  | INT x -> x
  | data -> failwithf !"expected INT, got: %{Sqlite3.Data#debug}" data ()
;;

let video_info_reader =
  let open Db.Reader.Let_syntax in
  let%map_open channel_id = by_name "channel_id" >>| string_exn
  and channel_title = by_name "channel_title" >>| string_exn
  and video_id = by_name "video_id" >>| string_exn
  and video_title = by_name "video_title" >>| string_exn in
  { Video_info.channel_id; channel_title; video_id; video_title }
;;

let iter_non_watched_videos t ~f =
  let stmt = force t.select_non_watched_videos in
  Db.Stmt.select Arity0 stmt video_info_reader ~f
;;

let video_stats t =
  let int_reader =
    let open Db.Reader.Let_syntax in
    Db.Reader.by_index 0 >>| int64_exn >>| Int64.to_int_exn
  in
  let%bind total_videos =
    Db.Stmt.select_one Arity0 (force t.select_count_total_videos) int_reader
  in
  let%bind watched_videos =
    Db.Stmt.select_one Arity0 (force t.select_count_watched_videos) int_reader
  in
  return
    { Stats.total_videos
    ; watched_videos
    ; unwatched_videos = total_videos - watched_videos
    }
;;

let add_video t (video_info : Video_info.t) ~mark_watched ~overwrite =
  (* TODO: [run_bind_by_name] *)
  let stmt =
    force (if overwrite then t.add_video_overwrite else t.add_video_no_overwrite)
  in
  let%bind () =
    Db.Stmt.run
      Arity4
      stmt
      (TEXT video_info.video_id)
      (TEXT video_info.video_title)
      (TEXT video_info.channel_id)
      (TEXT video_info.channel_title)
    >>| (ignore : int -> unit)
  in
  match mark_watched with
  | None -> return ()
  | Some state ->
    let watched =
      match state with
      | `Watched -> 1L
      | `Unwatched -> 0L
    in
    let%bind changes =
      Db.Stmt.run Arity2 (force t.mark_watched) (INT watched) (TEXT video_info.video_id)
    in
    if changes <> 1
    then
      Deferred.Or_error.error_s
        [%message "Failed to mark watched" ~video_id:(video_info.video_id : string)]
    else return ()
;;

let mark_watched t video_spec state =
  let watched =
    match state with
    | `Watched -> 1L
    | `Unwatched -> 0L
  in
  let video_id = Video_spec.video_id video_spec in
  let stmt = force t.mark_watched in
  match%bind Db.Stmt.run Arity2 stmt (INT watched) (TEXT video_id) with
  | 0 ->
    Deferred.Or_error.error_s
      [%message "No rows were changed" (video_id : string) (watched : int64)]
  | 1 -> return ()
  | changes ->
    Deferred.Or_error.error_s
      [%message "Unexpected change count" (video_id : string) (changes : int)]
;;

let get_random_unwatched_video t =
  Db.Stmt.select_one Arity0 (force t.get_random_unwatched_video) video_info_reader
;;
