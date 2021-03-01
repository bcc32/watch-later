open! Core
open! Async
open! Import

type t =
  | These of Video_id.t list
  | Filter of Filter.t

let param ~default =
  let open Command.Let_syntax in
  let filter =
    let%map filter = Filter.param in
    if Filter.is_empty filter then None else Some (Filter filter)
  in
  let video_ids =
    match%map Params.videos with
    | [] -> None
    | _ :: _ as nonempty_videos -> Some (These nonempty_videos)
  in
  Command.Param.choose_one [ filter; video_ids ] ~if_nothing_chosen:(Default_to default)
;;
