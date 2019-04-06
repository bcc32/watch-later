open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let main ~dbpath ~video_specs =
  let%bind db =
    Or_error.try_with (fun () -> Video_db.open_file_exn dbpath) |> Deferred.return
  in
  Deferred.Or_error.List.iter video_specs ~f:(fun spec ->
    Video_db.mark_watched db spec;
    return ())
;;

let command =
  Command.async_or_error
    ~summary:"Mark video(s) as watched"
    (let%map_open.Command.Let_syntax () = return ()
     and dbpath = Params.dbpath
     and video_specs =
       anon (non_empty_sequence_as_list ("VIDEO" %: Video_spec.arg_type))
     in
     fun () -> main ~dbpath ~video_specs)
;;
