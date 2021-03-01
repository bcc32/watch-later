open! Core
open! Async
open! Import

type t =
  | These of Video_id.t list
  | Filter of Filter.t

let param ~default =
  let%map_open.Command filter = Filter.param
  and video_ids = Params.videos in
  match video_ids, Filter.is_empty filter with
  | _ :: _, false -> failwith "Cannot specify both video IDs and filter"
  | _ :: _, true -> These video_ids
  | [], false -> Filter filter
  | [], true -> default
;;
