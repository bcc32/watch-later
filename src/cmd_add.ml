open! Core
open! Async
open! Import

(* FIXME: This function is now quite convoluted.  Try to simplify. *)
let main ~api ~dbpath ~mark_watched ~overwrite ~videos_or_playlist =
  let%bind playlist_items_to_delete =
    Video_db.with_file_and_txn dbpath ~f:(fun db ->
      let process_video_info =
        match mark_watched with
        | None -> fun video_info -> Video_db.add_video db video_info ~overwrite
        | Some state ->
          fun video_info ->
            let%bind () = Video_db.add_video db video_info ~overwrite in
            let%bind () = Video_db.mark_watched db video_info.video_id state in
            return ()
      in
      let process_video_infos video_infos =
        match%map.Deferred
          video_infos
          |> Pipe.filter_map' ~f:(fun video_info ->
            Deferred.map
              ~f:Result.error
              (let%bind video_info = Deferred.return video_info in
               process_video_info video_info))
          |> Pipe.to_list
        with
        | [] -> Ok ()
        | _ :: _ as errors -> Error (Error.of_list errors)
      in
      let%bind playlist_items_to_delete =
        match videos_or_playlist with
        | `Videos video_ids ->
          let video_ids_to_lookup = video_ids |> Pipe.of_list in
          let video_ids_to_lookup =
            if overwrite
            then video_ids_to_lookup
            else
              video_ids_to_lookup
              |> Pipe.filter_map' ~f:(fun video_id ->
                if%map.Deferred
                  Video_db.mem db video_id |> Deferred.Or_error.ok_exn
                then None
                else Some video_id)
          in
          let%bind () =
            video_ids_to_lookup |> Youtube_api.get_video_info api |> process_video_infos
          in
          return []
        | `Playlist (playlist_id, delete_after_processing) ->
          let pipe = Youtube_api.get_playlist_items api playlist_id in
          let video_infos, playlist_items_to_delete =
            let playlist_items, playlist_items_to_delete =
              if delete_after_processing
              then (
                let r1, r2 = Pipe.fork pipe ~pushback_uses:`Both_consumers in
                r1, r2 |> Pipe.to_list |> Deferred.map ~f:Or_error.combine_errors)
              else pipe, return []
            in
            ( Pipe.map playlist_items ~f:(Or_error.map ~f:Playlist_item.video_info)
            , playlist_items_to_delete )
          in
          let%bind () = process_video_infos video_infos in
          playlist_items_to_delete
      in
      return playlist_items_to_delete)
  in
  Deferred.Or_error.List.iter playlist_items_to_delete ~f:(fun item ->
    Youtube_api.delete_playlist_item api (Playlist_item.id item))
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
     and videos_or_playlist = Params.nonempty_videos_or_playlist in
     fun api -> main ~api ~dbpath ~mark_watched ~overwrite ~videos_or_playlist)
;;
