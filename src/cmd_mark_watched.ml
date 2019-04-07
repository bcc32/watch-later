open! Core
open! Async
open! Import

let main ~dbpath ~undo ~video_specs =
  Video_db.with_file dbpath ~f:(fun db ->
    Deferred.Or_error.List.iter video_specs ~f:(fun spec ->
      Video_db.mark_watched db spec (if undo then `Unwatched else `Watched)))
;;

let command =
  Command.async_or_error
    ~summary:"Mark video(s) as watched"
    (let%map_open.Command.Let_syntax () = return ()
     and dbpath = Params.dbpath
     and undo = flag "undo" no_arg ~doc:" mark as unwatched instead"
     and video_specs =
       anon (non_empty_sequence_as_list ("VIDEO" %: Video_spec.arg_type))
     in
     fun () -> main ~dbpath ~undo ~video_specs)
;;
