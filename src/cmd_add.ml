open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let main ~credentials ~dbpath ~overwrite ~video_specs =
  let%bind db =
    Or_error.try_with (fun () -> Video_db.open_file_exn dbpath) |> Deferred.return
  in
  let api = Youtube_api.create credentials in
  Deferred.Or_error.List.iter video_specs ~f:(fun spec ->
    let%bind video_info = Youtube_api.get_video_info api spec in
    Video_db.add_video_exn db video_info ~overwrite;
    return ())
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
