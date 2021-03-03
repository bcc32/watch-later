open! Core_kernel
open! Import

module Id =
  String_id.Make
    (struct
      let module_name = "Watch_later.Playlist_item.Id"
    end)
    ()

type t =
  { id : Id.t
  ; video_info : Video_info.t Lazy.t
  }
[@@deriving fields, sexp_of]

let of_json =
  let open Of_json.Let_syntax in
  let%map id = "id" @. string >>| Id.of_string
  and video_info =
    lazy_
      ("snippet"
       @. let%map channel_id = "videoOwnerChannelId" @. string
       and channel_title = "videoOwnerChannelTitle" @. string
       and video_id = "resourceId" @. "videoId" @. Video_id.of_json
       and video_title = "title" @. string in
       ({ channel_id; channel_title; video_id; video_title } : Video_info.t))
  in
  { id; video_info }
;;

let video_id t = (force t.video_info).video_id
let video_info t = force t.video_info
