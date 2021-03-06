open! Core
open! Async
open! Import

let browse_video video_id =
  Browse.url (Uri.of_string (sprintf !"https://youtu.be/%{Video_id}" video_id))
;;

let main ~dbpath ~mark_watched ~(which_videos : Which_videos.t) =
  Video_db.with_file_and_txn dbpath ~f:(fun db ->
    let%bind which_videos =
      match which_videos with
      | These ids -> return ids
      | Filter filter ->
        let%map video_id = Video_db.get_random_video db filter in
        [ video_id ]
    in
    Deferred.Or_error.List.iter which_videos ~f:(fun video_id ->
      let%bind () = browse_video video_id in
      if mark_watched then Video_db.mark_watched db video_id `Watched else return ()))
;;

let command =
  Command.async_or_error
    ~summary:"Open a video in $BROWSER and mark it watched."
    ~readme:(fun () ->
      {|
If video IDs are specified, process each video in sequence.

If a filter is specified, select one video matching the filter at random.

If neither video IDs nor filter is specified, defaults to selecting a random unwatched
video.
|})
    (let%map_open.Command () = return ()
     and dbpath = Params.dbpath
     and mark_watched =
       flag_optional_with_default_doc
         "-mark-watched"
         bool
         [%sexp_of: bool]
         ~default:true
         ~doc:"(true|false) mark video as watched (default true)"
     and which_videos = Which_videos.param ~default:(Filter Filter.unwatched) in
     fun () -> main ~dbpath ~mark_watched ~which_videos)
;;
