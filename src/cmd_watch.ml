open! Core
open! Async
open! Import

let browse_video video_id =
  Browse.url (Uri.of_string (sprintf !"https://youtu.be/%{Video_id}" video_id))
;;

module Which_videos = struct
  type t =
    | These of Video_id.t list
    | Filter of Video_db.Filter.t
end

let main ~dbpath ~mark_watched ~(which_videos : Which_videos.t) =
  Video_db.with_file_and_txn dbpath ~f:(fun db ->
    let%bind which_videos =
      match which_videos with
      | These ids -> return ids
      | Filter filter ->
        let%map video_id = Video_db.get_random_unwatched_video db filter in
        [ video_id ]
    in
    Deferred.Or_error.List.iter which_videos ~f:(fun video_id ->
      let%bind () = browse_video video_id in
      if mark_watched then Video_db.mark_watched db video_id `Watched else return ()))
;;

let command =
  Command.async_or_error
    ~summary:"Open a video in $BROWSER and mark it watched."
    (let%map_open.Command () = return ()
     and dbpath = Params.dbpath
     and mark_watched =
       flag_optional_with_default_doc
         "-mark-watched"
         bool
         [%sexp_of: bool]
         ~default:true
         ~doc:"(true|false) mark video as watched (default true)"
     and video_ids = Params.videos
     and filter = Video_db.Filter.param in
     fun () ->
       let which_videos : Which_videos.t =
         match video_ids, Video_db.Filter.is_empty filter with
         | _ :: _, false -> failwith "Cannot specify both video IDs and filter"
         | _ :: _, true -> These video_ids
         | [], _ -> Filter filter
       in
       main ~dbpath ~mark_watched ~which_videos)
;;
