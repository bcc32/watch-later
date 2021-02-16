open! Core
open! Async
open! Import

let main ~api ~dbpath ~mark_watched ~overwrite ~video_ids =
  Video_db.with_file_and_txn dbpath ~f:(fun db ->
    video_ids
    |> Pipe.of_list
    |> Youtube_api.get_video_info' api
    |> Pipe.fold ~init:[] ~f:(fun accum video_info ->
      let result =
        let%bind video_info = Deferred.return video_info in
        let%bind already_present = Video_db.mem db video_info.video_id in
        if already_present && not overwrite
        then (
          match mark_watched with
          | None -> return ()
          | Some state -> Video_db.mark_watched db video_info.video_id state)
        else (
          let%bind video_info =
            Youtube_api.get_video_info api video_info.video_id
          in
          Video_db.add_video db video_info ~mark_watched ~overwrite)
      in
      let%map.Deferred result = result in
      result :: accum)
    |> Deferred.map ~f:(Or_error.combine_errors_unit << List.rev))
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
