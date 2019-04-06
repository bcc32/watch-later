open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let main ~credentials ~dbpath ~video_specs =
  let%bind db =
    Or_error.try_with (fun () -> Db.open_file_exn dbpath) |> Deferred.return
  in
  let api = Youtube_api.create credentials in
  Deferred.Or_error.List.iter video_specs ~f:(fun spec ->
    let%bind video_info = Youtube_api.get_video_info api spec in
    Db.add_video_overwrite_exn db video_info;
    return ())
;;

let command =
  Command.async_or_error
    ~summary:"Add video(s) to queue"
    (let%map_open.Command.Let_syntax () = return ()
     and credentials = Youtube_api.Credentials.param
     and dbpath = Params.dbpath
     and video_specs =
       anon (non_empty_sequence_as_list ("VIDEO" %: Video_spec.arg_type))
     in
     fun () -> main ~credentials ~dbpath ~video_specs)
;;
