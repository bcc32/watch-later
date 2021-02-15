open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

module What_to_show = struct
  type t =
    | Video_info
    | Json of { extra_parts : string list }

  let param =
    let open Command.Let_syntax in
    let%map_open () = return ()
    and json = flag "json" no_arg ~doc:" Display raw JSON API response"
    and parts =
      flag
        "part"
        (listed string)
        ~doc:
          "PART include PART in the JSON response (see \
           https://developers.google.com/youtube/v3/docs/videos/list).  Can be passed \
           multiple times."
    in
    match parts with
    | [] -> if json then Json { extra_parts = [] } else Video_info
    | _ :: _ when not json -> failwith "[-part] can only be used with [-json]"
    | _ :: _ as extra_parts -> Json { extra_parts }
  ;;
end

let main ~api ~video_id ~what_to_show =
  match (what_to_show : What_to_show.t) with
  | Video_info ->
    let%map video_info = Youtube_api.get_video_info api video_id in
    print_s [%sexp (video_info : Video_info.t)]
  | Json { extra_parts } ->
    let%map json =
      Youtube_api.get_video_json api video_id ~parts:("snippet" :: extra_parts)
    in
    print_string (Yojson.Basic.pretty_to_string json)
;;

let command =
  Youtube_api.command
    ~summary:"Debug YouTube API calls"
    (let%map_open.Command () = return ()
     and video_id = Params.video
     and what_to_show = What_to_show.param in
     fun api -> main ~api ~video_id ~what_to_show)
;;
