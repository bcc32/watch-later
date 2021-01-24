open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

module Which_videos = struct
  type t =
    | These of Video_id.t list
    | Filter of Video_db.Filter.t
end

let main ~dbpath ~watched ~(which_videos : Which_videos.t) =
  Video_db.with_file dbpath ~f:(fun db ->
    match which_videos with
    | These ids ->
      Deferred.Or_error.List.iter ids ~f:(fun video_id ->
        match%bind Video_db.get db video_id with
        | None ->
          eprintf !"Video %{Video_id} not found\n" video_id;
          return ()
        | Some (video_info, watched) ->
          print_s [%message (video_info : Video_info.t) (watched : bool)];
          return ())
    | Filter filter ->
      let%bind videos = Video_db.get_videos db filter ~watched in
      List.iter videos ~f:(fun (video_info, watched) ->
        print_s [%message (video_info : Video_info.t) (watched : bool)]);
      return ())
;;

let command =
  Command.async_or_error
    ~summary:"List videos according to filter."
    (let%map_open.Command () = return ()
     and dbpath = Params.dbpath
     and video_ids = Params.videos
     and filter = Video_db.Filter.param
     and watched =
       flag
         "watched"
         (optional bool)
         ~doc:"BOOL Restrict to videos with watched status BOOL"
     in
     fun () ->
       let which_videos : Which_videos.t =
         match video_ids, Video_db.Filter.is_empty filter with
         | _ :: _, false -> failwith "Cannot specify both video IDs and filter"
         | _ :: _, true -> These video_ids
         | [], _ -> Filter filter
       in
       main ~dbpath ~watched ~which_videos)
;;
