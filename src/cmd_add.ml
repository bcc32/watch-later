open! Core
open! Async
open! Import

let main ~api ~dbpath ~mark_watched ~overwrite ~video_ids =
  Video_db.with_file_and_txn dbpath ~f:(fun db ->
    let video_ids_to_lookup = video_ids |> Pipe.of_list in
    let video_ids_to_lookup =
      if overwrite
      then video_ids_to_lookup
      else
        video_ids_to_lookup
        |> Pipe.filter_map' ~f:(fun video_id ->
          if%map.Deferred Video_db.mem db video_id |> Deferred.Or_error.ok_exn
          then None
          else Some video_id)
    in
    let%bind () =
      match%map.Deferred
        video_ids_to_lookup
        |> Youtube_api.get_video_info' api
        |> Pipe.filter_map' ~f:(fun video_info ->
          Deferred.map
            ~f:Result.error
            (let%bind video_info = Deferred.return video_info in
             Video_db.add_video db video_info ~overwrite))
        |> Pipe.to_list
      with
      | [] -> Ok ()
      | _ :: _ as errors -> Error (Error.of_list errors)
    in
    match mark_watched with
    | None -> return ()
    | Some state ->
      Deferred.Or_error.List.iter video_ids ~f:(fun video_id ->
        Video_db.mark_watched db video_id state))
;;

let command =
  Youtube_api.command
    ~summary:"Add video(s) to queue"
    (let%map_open.Command () = return ()
     and dbpath = Params.dbpath
     and mark_watched =
       flag
         "-mark-watched"
         (optional bool)
         ~doc:"(true|false) mark video as watched (default do nothing)"
       >>| Option.map ~f:(function
         | true -> `Watched
         | false -> `Unwatched)
     and overwrite =
       flag
         "-overwrite"
         no_arg
         ~doc:" overwrite existing entries (default skip)"
         ~aliases:[ "-f" ]
     and video_ids = Params.nonempty_videos in
     fun api -> main ~api ~dbpath ~mark_watched ~overwrite ~video_ids)
;;
