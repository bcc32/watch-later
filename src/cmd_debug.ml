open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let main ~credentials ~video_spec =
  let api = Youtube_api.create credentials in
  let%bind video_info = Youtube_api.get_video_info api video_spec in
  print_s [%sexp (video_info : Video_info.t)];
  return ()
;;

let command =
  Command.async_or_error
    ~summary:"Debug YouTube API calls"
    (let%map_open.Command.Let_syntax () = return ()
     and credentials = Youtube_api.Credentials.param
     and video_spec = Params.video in
     fun () -> main ~credentials ~video_spec)
;;
