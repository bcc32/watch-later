open! Core
open! Async
open! Import

type t = Sqlite3.db

(* FIXME: This should be done asynchronously, in a thread. *)
let open_file dbpath = Sqlite3.db_open ~mode:`READONLY dbpath

(* FIXME: Factor out error code checking. *)
let iter_non_watched_videos db ~f =
  match
    Sqlite3.exec_not_null_no_headers
      db
      {|
SELECT channel_id, channel_title, video_id, video_title
FROM videos
WHERE NOT watched;
|}
      ~cb:(fun row ->
        match row with
        | [| channel_id; channel_title; video_id; video_title |] ->
          f { Video_info.channel_id; channel_title; video_id; video_title }
        | _ -> raise_s [%message "wrong number of fields" (row : string array)])
  with
  | OK -> ()
  | rc -> print_s [%message "non-OK rc" (Sqlite3.Rc.to_string rc : string)]
;;

let video_stats db =
  let total_videos = Set_once.create () in
  let watched_videos = Set_once.create () in
  (match
     Sqlite3.exec_not_null_no_headers
       db
       {|
SELECT COUNT(*) FROM videos;
|}
       ~cb:(fun row ->
         match row with
         | [| count |] -> Set_once.set_exn total_videos [%here] (Int.of_string count)
         | _ -> raise_s [%message "wrong number of fields" (row : string array)])
   with
   | OK -> ()
   | rc -> print_s [%message "non-OK rc" (Sqlite3.Rc.to_string rc : string)]);
  (match
     Sqlite3.exec_not_null_no_headers
       db
       {|
SELECT COUNT(*) FROM videos
WHERE watched;
|}
       ~cb:(fun row ->
         match row with
         | [| count |] -> Set_once.set_exn watched_videos [%here] (Int.of_string count)
         | _ -> raise_s [%message "wrong number of fields" (row : string array)])
   with
   | OK -> ()
   | rc -> print_s [%message "non-OK rc" (Sqlite3.Rc.to_string rc : string)]);
  let total_videos = Set_once.get_exn total_videos [%here] in
  let watched_videos = Set_once.get_exn watched_videos [%here] in
  let unwatched_videos = total_videos - watched_videos in
  { Stats.total_videos; watched_videos; unwatched_videos }
;;
