open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let main ~credentials ~dbpath ~mark_watched ~overwrite ~video_ids =
  Video_db.with_file dbpath ~f:(fun db ->
    let api = Youtube_api.create credentials in
    Deferred.List.map video_ids ~f:(fun spec ->
      (* FIXME: No need to fetch video_info for videos that are already present,
         if overwrite=false. *)
      let%bind video_info = Youtube_api.get_video_info api spec in
      Video_db.add_video db video_info ~mark_watched ~overwrite)
    |> Deferred.map ~f:Or_error.combine_errors_unit)
;;

let command =
  Command.async_or_error
    ~summary:"Add video(s) to queue"
    (let%map_open.Command () = return ()
     and credentials = Youtube_api.Credentials.param
     and dbpath = Params.dbpath
     and mark_watched =
       flag
         "mark-watched"
         (optional bool)
         ~doc:"(true|false) mark video as watched (default do nothing)"
       >>| Option.map ~f:(function
         | true -> `Watched
         | false -> `Unwatched)
     and overwrite =
       flag
         "overwrite"
         no_arg
         ~doc:" overwrite existing entries (default skip)"
         ~aliases:[ "f" ]
     and video_ids = Params.nonempty_videos in
     fun () -> main ~credentials ~dbpath ~mark_watched ~overwrite ~video_ids)
;;
