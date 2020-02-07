open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let browse_video video_spec =
  let browser =
    match Bos.OS.Env.(parse "BROWSER" (some cmd)) ~absent:None with
    | Ok cmd -> cmd
    | Error (`Msg s) ->
      raise_s [%message "Error parsing BROWSER environment variable" ~_:(s : string)]
  in
  let uri = "https://youtu.be/" ^ Video_spec.video_id video_spec in
  Webbrowser.reload ?browser uri
  |> Result.map_error ~f:(fun (`Msg s) -> Error.of_string s)
;;

let main ~dbpath ~mark_watched ~video_specs =
  Video_db.with_file dbpath ~f:(fun db ->
    let%bind video_specs =
      match video_specs with
      | _ :: _ as specs -> return specs
      | [] ->
        let%map video_info = Video_db.get_random_unwatched_video db in
        [ Video_spec.of_video_id video_info.video_id ]
    in
    Deferred.Or_error.List.iter video_specs ~f:(fun video_spec ->
      let%bind () = Deferred.return (browse_video video_spec) in
      if mark_watched then Video_db.mark_watched db video_spec `Watched else return ()))
;;

let command =
  Command.async_or_error
    ~summary:"Open a video in $BROWSER and mark it watched."
    (let%map_open.Command () = return ()
     and dbpath = Params.dbpath
     and mark_watched =
       flag_optional_with_default_doc
         "mark-watched"
         bool
         [%sexp_of: bool]
         ~default:true
         ~doc:"(true|false) mark video as watched (default true)"
     and video_specs = Params.videos in
     fun () -> main ~dbpath ~mark_watched ~video_specs)
;;
