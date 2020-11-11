open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

module Clear = struct
  let command =
    Command.async_or_error
      ~summary:"Remove all videos from a playlist"
      (let%map_open.Command () = return ()
       and credentials = Youtube_api.Credentials.param
       and playlist_id = anon ("PLAYLIST-ID" %: Playlist_id.arg_type) in
       fun () ->
         let youtube_api = Youtube_api.create credentials in
         Youtube_api.clear_playlist youtube_api playlist_id)
  ;;
end

(* FIXME: Factor out the credentials and API creation boilerplate. *)
module List = struct
  let command =
    Command.async_or_error
      ~summary:"List the IDs of the videos in a playlist"
      (let%map_open.Command () = return ()
       and credentials = Youtube_api.Credentials.param
       and playlist_id = anon ("PLAYLIST-ID" %: Playlist_id.arg_type) in
       fun () ->
         let youtube_api = Youtube_api.create credentials in
         let%bind items = Youtube_api.get_playlist_items youtube_api playlist_id in
         List.iter items ~f:(fun item -> printf !"%{Video_id}\n" item.video_id);
         return ())
  ;;
end

module Remove_video = struct
  let command =
    Command.async_or_error
      ~summary:"Remove videos from a playlist"
      (let%map_open.Command () = return ()
       and credentials = Youtube_api.Credentials.param
       and playlist_id = anon ("PLAYLIST-ID" %: Playlist_id.arg_type)
       and videos =
         anon (non_empty_sequence_as_list ("VIDEO-SPEC" %: Video_spec.arg_type))
       in
       fun () ->
         let youtube_api = Youtube_api.create credentials in
         Deferred.Or_error.List.iter videos ~f:(fun video_spec ->
           (* TODO: Add [Video_id.arg_type] which allows video URLs, and get rid
              of the extraneous [Video_spec.t] type. *)
           let video_id = Video_spec.video_id video_spec in
           let%bind items =
             Youtube_api.get_playlist_items youtube_api playlist_id ~video_id
           in
           Deferred.Or_error.List.iter items ~f:(fun item ->
             Youtube_api.delete_playlist_item youtube_api item.id)))
  ;;
end

let command =
  Command.group
    ~summary:"Commands for managing playlists"
    [ "clear", Clear.command; "list", List.command; "remove-video", Remove_video.command ]
;;
