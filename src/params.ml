open! Core
open! Async
open! Import

let dbpath =
  let default_db_path = Watch_later_directories.default_db_path in
  let open Command.Param in
  flag
    "-dbpath"
    (optional_with_default default_db_path Filename.arg_type)
    ~doc:
      "FILE path to database file (default is $XDG_DATA_HOME/watch-later/watch-later.db)"
;;

let video =
  let%map_open.Command () = return ()
  and anon = anon (maybe ("VIDEO" %: Video_id.Plain_or_in_url.arg_type))
  and escaped =
    flag "--" escape ~doc:"VIDEO escape a video whose ID may start with [-]"
  in
  match
    Option.to_list anon
    @ List.map (Option.value escaped ~default:[]) ~f:Video_id.Plain_or_in_url.of_string
  with
  | [] -> raise_s [%message "expected exactly one video"]
  | [ spec ] -> spec
  | _ :: _ as specs ->
    raise_s [%message "expected exactly one video" (specs : Video_id.t list)]
;;

let videos =
  let%map_open.Command () = return ()
  and anons = anon (sequence ("VIDEO" %: Video_id.Plain_or_in_url.arg_type))
  and escaped =
    flag "--" escape ~doc:"VIDEO escape videos whose IDs may start with [-]"
  in
  anons
  @ List.map (Option.value escaped ~default:[]) ~f:Video_id.Plain_or_in_url.of_string
;;

let nonempty_videos =
  match%map.Command videos with
  | [] -> raise_s [%message "expected at least one video"]
  | _ :: _ as specs -> specs
;;

let nonempty_videos_or_playlist =
  let open Command.Param in
  let playlist =
    flag
      "-playlist"
      (optional Playlist_id.Plain_or_in_url.arg_type)
      ~doc:
        "PLAYLIST specify videos in PLAYLIST rather than individual command-line \
         arguments"
  in
  let%map.Command videos = videos
  and playlist = playlist in
  match videos, playlist with
  | (_ :: _ as videos), None -> `Videos videos
  | [], Some playlist_id -> `Playlist playlist_id
  | [], None -> raise_s [%message "Neither videos nor playlist specified"]
  | _ :: _, Some _ -> raise_s [%message "Videos and playlist may not both be specified"]
;;
