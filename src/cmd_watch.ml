open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let browse_video video_spec =
  let uri = "https://youtu.be/" ^ Video_spec.video_id video_spec in
  Webbrowser.reload uri |> Result.map_error ~f:(fun (`Msg s) -> Error.of_string s)
;;

let main ~dbpath ~mark_watched ~video_spec =
  let%bind db =
    Or_error.try_with (fun () -> Video_db.open_file_exn dbpath) |> Deferred.return
  in
  let video_spec =
    match video_spec with
    | Some spec -> spec
    | None ->
      let video_info = Video_db.get_random_unwatched_video_exn db in
      Video_spec.of_video_id video_info.video_id
  in
  let%bind () = Deferred.return (browse_video video_spec) in
  if mark_watched then Video_db.mark_watched db video_spec;
  return ()
;;

let command =
  Command.async_or_error
    ~summary:"Mark video(s) as watched"
    (let%map_open.Command.Let_syntax () = return ()
     and dbpath = Params.dbpath
     and mark_watched =
       flag
         "mark-watched"
         (optional_with_default true bool)
         ~doc:"(true|false) mark video as watched (default true)"
     and video_spec = anon (maybe ("VIDEO" %: Video_spec.arg_type)) in
     fun () -> main ~dbpath ~mark_watched ~video_spec)
;;
