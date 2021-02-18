open! Core
open! Async
open! Import

module Get_video = struct
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

  let main ~api ~video_ids ~what_to_show =
    let video_ids = Pipe.of_list video_ids in
    match (what_to_show : What_to_show.t) with
    | Video_info ->
      Youtube_api.get_video_info' api video_ids
      |> Pipe.iter_without_pushback ~f:(fun video_info ->
        print_s [%sexp (video_info : Video_info.t Or_error.t)])
      |> Deferred.ok
    | Json { extra_parts } ->
      Youtube_api.get_video_json' api video_ids ~parts:("snippet" :: extra_parts)
      |> Pipe.iter_without_pushback ~f:(fun json ->
        print_endline (Yojson.Basic.pretty_to_string (ok_exn json)))
      |> Deferred.ok
  ;;

  let command =
    Youtube_api.command
      ~summary:"Debug YouTube API calls"
      (let%map_open.Command () = return ()
       and video_ids = Params.nonempty_videos
       and what_to_show = What_to_show.param in
       fun api -> main ~api ~video_ids ~what_to_show)
  ;;
end

let command = Command.group ~summary:"Debugging tools" [ "get-video", Get_video.command ]
