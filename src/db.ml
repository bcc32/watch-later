open! Core
open! Async
open! Import

type t = Sqlite3.db

let open_file dbpath = Sqlite3.db_open ~mode:`READONLY dbpath

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
          f { Video.channel_id; channel_title; video_id; video_title }
        | _ -> raise_s [%message "wrong number of fields" (row : string array)])
  with
  | Sqlite3.Rc.OK -> ()
  | rc -> print_s [%message "non-OK rc" (Sqlite3.Rc.to_string rc : string)]
;;
