open! Core
open! Async
open! Import

type t =
  { db : Sqlite3.db
  ; setup_schema : ([ `Non_select ], Db.Arity.t0) Db.Stmt.t Lazy.t
  ; select_non_watched_videos : ([ `Select ], Db.Arity.t0) Db.Stmt.t Lazy.t
  ; select_count_total_videos : ([ `Select ], Db.Arity.t0) Db.Stmt.t Lazy.t
  ; select_count_watched_videos : ([ `Select ], Db.Arity.t0) Db.Stmt.t Lazy.t
  ; add_video_overwrite : ([ `Non_select ], Db.Arity.t4) Db.Stmt.t Lazy.t
  ; add_video_no_overwrite : ([ `Non_select ], Db.Arity.t4) Db.Stmt.t Lazy.t
  ; mark_watched : ([ `Non_select ], Db.Arity.t1) Db.Stmt.t Lazy.t
  ; get_random_unwatched_video : ([ `Select ], Db.Arity.t0) Db.Stmt.t Lazy.t
  }

let setup_schema db =
  Db.Stmt.prepare_exn
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
  Db.Stmt.prepare_exn
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
  Db.Stmt.prepare_exn db Select Arity0 {|
SELECT COUNT(*) FROM videos;
|}
;;

let select_count_watched_videos db =
  Db.Stmt.prepare_exn db Select Arity0 {|
SELECT COUNT(*) FROM videos
WHERE watched;
|}
;;

let add_video db ~conflict_resolution =
  let sql =
    sprintf
      {|
INSERT OR %s INTO videos
(video_id, video_title, channel_id, channel_title, watched)
VALUES (?, ?, ?, ?, 0);
|}
      conflict_resolution
  in
  Db.Stmt.prepare_exn db Non_select Arity4 sql
;;

let add_video_overwrite db = add_video db ~conflict_resolution:"REPLACE"
let add_video_no_overwrite db = add_video db ~conflict_resolution:"IGNORE"

let mark_watched db =
  Db.Stmt.prepare_exn
    db
    Non_select
    Arity1
    {|
UPDATE videos SET watched = 1
WHERE video_id = ?;
|}
;;

let get_random_unwatched_video db =
  Db.Stmt.prepare_exn
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
  Db.Stmt.run_exn stmt
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
  if should_setup_schema then do_setup_schema t;
  t
;;

(* FIXME: This should be done asynchronously, in a thread. *)
let open_file_exn ?should_setup_schema dbpath =
  create ?should_setup_schema (Sqlite3.db_open dbpath)
;;

let rec close t =
  if Sqlite3.db_close t.db
  then return ()
  else (
    let%bind () = Clock_ns.after (Time_ns.Span.of_sec 0.05) in
    close t)
;;

let with_file_exn ?should_setup_schema dbpath ~f =
  let t = open_file_exn ?should_setup_schema dbpath in
  Monitor.protect (fun () -> f t) ~finally:(fun () -> close t)
;;

let string_exn (data : Sqlite3.Data.t) =
  match data with
  | TEXT x | BLOB x -> x
  | data -> failwithf !"expected TEXT or BLOB, got: %{Sqlite3.Data}" data ()
;;

let int64_exn (data : Sqlite3.Data.t) =
  match data with
  | INT x -> x
  | data -> failwithf !"expected INT, got: %{Sqlite3.Data}" data ()
;;

let video_info_reader =
  let open Db.Reader.Let_syntax in
  let%map_open channel_id = by_name "channel_id" >>| string_exn
  and channel_title = by_name "channel_title" >>| string_exn
  and video_id = by_name "video_id" >>| string_exn
  and video_title = by_name "video_title" >>| string_exn in
  { Video_info.channel_id; channel_title; video_id; video_title }
;;

let iter_non_watched_videos_exn t ~f =
  let stmt = force t.select_non_watched_videos in
  Db.Stmt.select_exn stmt video_info_reader ~f
;;

let video_stats_exn t =
  let int_reader =
    let open Db.Reader.Let_syntax in
    Db.Reader.by_index 0 >>| int64_exn >>| Int64.to_int_exn
  in
  let total_videos =
    let result = Set_once.create () in
    let stmt = force t.select_count_total_videos in
    Db.Stmt.select_exn stmt int_reader ~f:(fun count ->
      Set_once.set_exn result [%here] count);
    Set_once.get_exn result [%here]
  in
  let watched_videos =
    let result = Set_once.create () in
    let stmt = force t.select_count_watched_videos in
    Db.Stmt.select_exn stmt int_reader ~f:(fun count ->
      Set_once.set_exn result [%here] count);
    Set_once.get_exn result [%here]
  in
  { Stats.total_videos
  ; watched_videos
  ; unwatched_videos = total_videos - watched_videos
  }
;;

let add_video_exn t (video_info : Video_info.t) ~overwrite =
  (* TODO: [run_bind_by_name] *)
  let stmt =
    force (if overwrite then t.add_video_overwrite else t.add_video_no_overwrite)
  in
  Db.Stmt.run_exn
    stmt
    (TEXT video_info.video_id)
    (TEXT video_info.video_title)
    (TEXT video_info.channel_id)
    (TEXT video_info.channel_title)
;;

let mark_watched t video_spec =
  let video_id = Video_spec.video_id video_spec in
  let stmt = force t.mark_watched in
  Db.Stmt.run_exn stmt (TEXT video_id)
;;

let get_random_unwatched_video_exn t =
  let stmt = force t.get_random_unwatched_video in
  let result = Set_once.create () in
  Db.Stmt.select_exn stmt video_info_reader ~f:(fun video_info ->
    Set_once.set_exn result [%here] video_info);
  match Set_once.get result with
  | None -> failwith "no unwatched videos"
  | Some video_info -> video_info
;;
