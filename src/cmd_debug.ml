open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let main ~credentials ~video_spec ~json =
  let api = Youtube_api.create credentials in
  if json
  then (
    let%map json = Youtube_api.get_video_json api video_spec in
    print_string (Yojson.Basic.pretty_to_string json))
  else (
    let%map video_info = Youtube_api.get_video_info api video_spec in
    print_s [%sexp (video_info : Video_info.t)])
;;

let command =
  Command.async_or_error
    ~summary:"Debug YouTube API calls"
    (let%map_open.Command.Let_syntax () = return ()
     and credentials = Youtube_api.Credentials.param
     and video_spec = Params.video
     and json = flag "json" no_arg ~doc:" Display raw JSON API response" in
     fun () -> main ~credentials ~video_spec ~json)
;;
