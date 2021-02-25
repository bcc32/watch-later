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
  ; video_info : Video_info.t
  }
[@@deriving fields, sexp_of]

let of_json json =
  let open Json.Util in
  let id = json |> member "id" |> to_string |> Id.of_string in
  let video_info =
    let snippet = json |> member "snippet" in
    let channel_id = snippet |> member "videoOwnerChannelId" |> to_string in
    let channel_title = snippet |> member "videoOwnerChannelTitle" |> to_string in
    let video_id =
      snippet
      |> member "resourceId"
      |> member "videoId"
      |> to_string
      |> Video_id.of_string
    in
    let video_title = snippet |> member "title" |> to_string in
    ({ channel_id; channel_title; video_id; video_title } : Video_info.t)
  in
  { id; video_info }
;;

let video_id t = t.video_info.video_id
