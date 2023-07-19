open! Core
open! Async
open! Import

(* TODO: Factor out playlist_id param. *)
module Append_videos = struct
  let command =
    Youtube_api.command
      ~summary:"Append video(s) to a playlist"
      (let%map_open.Command () = return ()
       and playlist_id = anon ("PLAYLIST-ID" %: Playlist_id.Plain_or_in_url.arg_type)
       and videos = Params.nonempty_videos in
       fun api ->
         Deferred.Or_error.List.iter videos ~how:`Sequential ~f:(fun video_id ->
           Youtube_api.append_video_to_playlist api playlist_id video_id))
  ;;
end

module Dedup = struct
  let command =
    Youtube_api.command
      ~summary:"Remove duplicate videos in a playlist"
      (let%map_open.Command () = return ()
       and playlist_id = anon ("PLAYLIST-ID" %: Playlist_id.Plain_or_in_url.arg_type) in
       fun api ->
         let%bind items =
           Youtube_api.get_playlist_items api playlist_id
           |> Pipe.to_list
           |> Deferred.map ~f:Or_error.combine_errors
         in
         let items =
           List.dedup_and_sort
             items
             ~compare:(Comparable.lift ~f:Playlist_item.id [%compare: Playlist_item.Id.t])
         in
         let _, duplicate_video_items =
           List.fold
             items
             ~init:(Set.empty (module Video_id), [])
             ~f:(fun (seen_video_ids, duplicates) item ->
               let video_id = Playlist_item.video_id item in
               if Set.mem seen_video_ids video_id
               then seen_video_ids, item :: duplicates
               else Set.add seen_video_ids video_id, duplicates)
         in
         let%bind () =
           Deferred.Or_error.List.iter
             duplicate_video_items
             ~how:`Sequential
             ~f:(fun item ->
               [%log.global.info
                 "Deleting duplicate playlist item" (item : Playlist_item.t)];
               Youtube_api.delete_playlist_item api (Playlist_item.id item))
         in
         return ())
  ;;
end

module List = struct
  let command =
    Youtube_api.command
      ~summary:"List the IDs of the videos in a playlist"
      (let%map_open.Command () = return ()
       and playlist_id = anon ("PLAYLIST-ID" %: Playlist_id.Plain_or_in_url.arg_type) in
       fun api ->
         Youtube_api.get_playlist_items api playlist_id
         |> Pipe.iter_without_pushback ~f:(function
           | Ok item -> printf !"%{Video_id}\n" (Playlist_item.video_id item)
           | Error e -> [%log.global.error "" ~_:(e : Error.t)])
         |> Deferred.ok)
  ;;
end

module Remove_video = struct
  let command =
    Youtube_api.command
      ~summary:"Remove videos from a playlist"
      (let%map_open.Command () = return ()
       and playlist_id = anon ("PLAYLIST-ID" %: Playlist_id.Plain_or_in_url.arg_type)
       and videos = Params.nonempty_videos in
       fun api ->
         let videos = Set.of_list (module Video_id) videos in
         let%bind items =
           Youtube_api.get_playlist_items api playlist_id
           |> Pipe.to_list
           |> Deferred.map ~f:Or_error.combine_errors
         in
         Deferred.Or_error.List.iter items ~how:`Sequential ~f:(fun item ->
           if Set.mem videos (Playlist_item.video_id item)
           then Youtube_api.delete_playlist_item api (Playlist_item.id item)
           else return ()))
  ;;
end

let command =
  Command.group
    ~summary:"Commands for managing playlists"
    [ "append-videos", Append_videos.command
    ; "dedup", Dedup.command
    ; "list", List.command
    ; "remove-video", Remove_video.command
    ]
;;
