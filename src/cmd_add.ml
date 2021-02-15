open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let main ~api ~dbpath ~mark_watched ~overwrite ~video_ids =
  Video_db.with_file dbpath ~f:(fun db ->
    Deferred.List.map video_ids ~f:(fun video_id ->
      (* FIXME: This check/add should be in a transaction. *)
      let%bind already_present = Video_db.mem db video_id in
      if already_present && not overwrite
      then (
        match mark_watched with
        | None -> return ()
        | Some state -> Video_db.mark_watched db video_id state)
      else (
        let%bind video_info = Youtube_api.get_video_info api video_id in
        Video_db.add_video db video_info ~mark_watched ~overwrite))
    |> Deferred.map ~f:Or_error.combine_errors_unit)
;;

let command =
  Youtube_api.command
    ~summary:"Add video(s) to queue"
    (let%map_open.Command () = return ()
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
     fun api -> main ~api ~dbpath ~mark_watched ~overwrite ~video_ids)
;;
