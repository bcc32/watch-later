open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

module Append_videos = struct
  let command =
    Command.async_or_error
      ~summary:"Append video(s) to a playlist"
      (let%map_open.Command () = return ()
       and api = Youtube_api.param
       and playlist_id = anon ("PLAYLIST-ID" %: Playlist_id.Plain_or_in_url.arg_type)
       and videos = Params.nonempty_videos in
       fun () ->
         Deferred.Or_error.List.iter videos ~f:(fun video_id ->
           Youtube_api.append_video_to_playlist api playlist_id video_id))
  ;;
end

module Dedup = struct
  let command =
    Command.async_or_error
      ~summary:"Remove duplicate videos in a playlist"
      (let%map_open.Command () = return ()
       and api = Youtube_api.param
       and playlist_id = anon ("PLAYLIST-ID" %: Playlist_id.Plain_or_in_url.arg_type) in
       fun () ->
         let%bind items = Youtube_api.get_playlist_items api playlist_id in
         let _, duplicate_video_items =
           List.fold
             items
             ~init:(Set.empty (module Video_id), [])
             ~f:(fun (seen_video_ids, duplicates) ({ id = _; video_id } as item) ->
               if Set.mem seen_video_ids video_id
               then seen_video_ids, item :: duplicates
               else Set.add seen_video_ids video_id, duplicates)
         in
         let%bind () =
           Deferred.Or_error.List.iter duplicate_video_items ~f:(fun item ->
             Log.Global.info_s
               [%message "Deleting playlist item" (item : Playlist_item.t)];
             Youtube_api.delete_playlist_item api item.id)
         in
         return ())
  ;;
end

module List = struct
  let command =
    Command.async_or_error
      ~summary:"List the IDs of the videos in a playlist"
      (let%map_open.Command () = return ()
       and api = Youtube_api.param
       and playlist_id = anon ("PLAYLIST-ID" %: Playlist_id.Plain_or_in_url.arg_type) in
       fun () ->
         let%bind items = Youtube_api.get_playlist_items api playlist_id in
         List.iter items ~f:(fun item -> printf !"%{Video_id}\n" item.video_id);
         return ())
  ;;
end

module Remove_video = struct
  let command =
    Command.async_or_error
      ~summary:"Remove videos from a playlist"
      (let%map_open.Command () = return ()
       and api = Youtube_api.param
       and playlist_id = anon ("PLAYLIST-ID" %: Playlist_id.Plain_or_in_url.arg_type)
       and videos = Params.nonempty_videos in
       fun () ->
         Deferred.Or_error.List.iter videos ~f:(fun video_id ->
           let%bind items = Youtube_api.get_playlist_items api playlist_id ~video_id in
           Deferred.Or_error.List.iter items ~f:(fun item ->
             Youtube_api.delete_playlist_item api item.id)))
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
