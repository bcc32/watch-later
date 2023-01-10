open! Core
open! Async
open! Import

let browse_video video_id =
  Browse.url (Uri.of_string (sprintf !"https://youtu.be/%{Video_id}" video_id))
;;

let pick (videos : (Video_info.t * bool) list) ~random =
  match videos with
  | [] -> Deferred.Or_error.error_string "No unwatched videos matching filter"
  | _ :: _ as videos ->
    if random || not !Async_interactive.interactive
    then (
      let video_info, _ = List.random_element_exn videos in
      return [ video_info.video_id ])
    else (
      (* FIXME: Fzf hardcodes /usr/bin/fzf as the path.  NOOOO! *)
      match%bind
        Fzf.pick_one
          (Assoc
             (List.map videos ~f:(fun ((video_info, _) as x) ->
                [%string "%{video_info.channel_title} - %{video_info.video_title}"], x)))
      with
      | None -> Deferred.Or_error.error_string "No video selected"
      | Some (video_info, _) -> return [ video_info.video_id ])
;;

let main ~dbpath ~mark_watched ~random ~(which_videos : Which_videos.t) =
  Video_db.with_file_and_txn dbpath ~f:(fun db ->
    let%bind which_videos =
      match which_videos with
      | These ids -> return ids
      | Filter filter ->
        let%bind videos = Video_db.get_videos db filter |> Pipe.to_list |> Deferred.ok in
        pick videos ~random
    in
    Deferred.Or_error.List.iter which_videos ~f:(fun video_id ->
      let%bind () = browse_video video_id in
      if mark_watched then Video_db.mark_watched db video_id `Watched else return ()))
;;

let random_flag = "-random"

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
         ~doc:"(true|false) mark video as watched"
     and random =
       flag random_flag no_arg ~doc:" pick a random filtered video instead of prompting"
     and which_videos = Which_videos.param ~default:(Filter Filter.unwatched) in
     fun () ->
       (match which_videos with
        | These _ ->
          if random
          then
            raise_s
              [%message "Cannot use %{random_flag} with video ID anonymous arguments"]
        | Filter _ -> ());
       main ~dbpath ~mark_watched ~random ~which_videos)
;;
