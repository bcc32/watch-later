open! Core
open! Async
open! Import

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

let command =
  Command.group ~summary:"Commands for managing playlists" [ "clear", Clear.command ]
;;
