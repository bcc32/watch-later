open! Core
open! Async
open! Import

let dbpath =
  let%map_open.Command () = return ()
  and path =
    flag
      "-dbpath"
      (optional Filename.arg_type)
      ~doc:"FILE path to database file (default is $XDG_DATA_HOME/watch-later.db)"
  in
  match path with
  | Some path -> path
  | None ->
    let basedir =
      match Sys.getenv "XDG_DATA_HOME" with
      | Some path -> path
      | None -> Sys.getenv_exn "HOME" ^/ ".local" ^/ "share"
    in
    basedir ^/ "watch-later.db"
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
