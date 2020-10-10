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
  |> Result.map_error ~f:(fun (`Msg s) ->
    Error.create_s [%message "Error browsing video" s (video_spec : Video_spec.t)])
;;

module Which_videos = struct
  type t =
    | Specs of Video_spec.t list
    | Filter of Video_db.Filter.t
end

let main ~dbpath ~mark_watched ~(which_videos : Which_videos.t) =
  Video_db.with_file dbpath ~f:(fun db ->
    let%bind which_videos =
      match which_videos with
      | Specs specs -> return specs
      | Filter filter ->
        let%map video_info = Video_db.get_random_unwatched_video db filter in
        [ Video_spec.of_video_id video_info.video_id ]
    in
    Deferred.Or_error.List.iter which_videos ~f:(fun video_spec ->
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
     and video_specs = Params.videos
     and filter = Params.filter in
     fun () ->
       let which_videos : Which_videos.t =
         match video_specs, Video_db.Filter.is_empty filter with
         | _ :: _, false -> failwith "Cannot specify both video IDs and filter"
         | _ :: _, true -> Specs video_specs
         | [], _ -> Filter filter
       in
       main ~dbpath ~mark_watched ~which_videos)
;;
