open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let main ~credentials ~dbpath ~overwrite ~video_specs =
  Video_db.with_file dbpath ~f:(fun db ->
    let api = Youtube_api.create credentials in
    Deferred.Or_error.List.iter video_specs ~f:(fun spec ->
      let%bind video_info = Youtube_api.get_video_info api spec in
      Video_db.add_video db video_info ~overwrite))
;;

let command =
  Command.async_or_error
    ~summary:"Add video(s) to queue"
    (let%map_open.Command.Let_syntax () = return ()
     and credentials = Youtube_api.Credentials.param
     and dbpath = Params.dbpath
     and overwrite =
       flag
         "overwrite"
         no_arg
         ~doc:" overwrite existing entries (default skip)"
         ~aliases:[ "f" ]
     and video_specs =
       anon (non_empty_sequence_as_list ("VIDEO" %: Video_spec.arg_type))
     in
     fun () -> main ~credentials ~dbpath ~overwrite ~video_specs)
;;
