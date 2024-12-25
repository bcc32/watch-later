open! Core
open! Async
open! Import

let main ~dbpath ~id ~json ~(which_videos : Which_videos.t) =
  let print ((video_info : Video_info.t), watched) =
    if id
    then printf !"%{Video_id}\n" video_info.video_id
    else if json
    then
      print_endline
        (match video_info with
         (* FIXME: derive *)
         | { channel_id; channel_title; video_id; video_title; published_at; duration } ->
           Json.to_string
             (`Object
                 [ "channel_id", `String channel_id
                 ; "channel_title", `String channel_title
                 ; "video_id", `String (Video_id.to_string video_id)
                 ; "video_title", `String video_title
                 ; ( "published_at"
                   , Option.value_map published_at ~default:`Null ~f:(fun published_at ->
                       `String
                         (Time_ns.to_string_iso8601_basic published_at ~zone:Timezone.utc))
                   )
                 ; ( "duration"
                   , Option.value_map duration ~default:`Null ~f:(fun duration ->
                       `Number (Int.to_string (Time_ns.Span.to_int_sec duration))) )
                 ]))
    else print_s [%message (video_info : Video_info.t) (watched : bool)]
  in
  Video_db.with_file_and_txn dbpath ~f:(fun db ->
    match which_videos with
    | These ids ->
      Deferred.Or_error.List.iter ids ~how:`Sequential ~f:(fun video_id ->
        let%bind info =
          match%bind Video_db.get db video_id with
          | Some info -> return info
          | None ->
            Deferred.Or_error.error_s [%message "Video not found" (video_id : Video_id.t)]
        in
        print info;
        return ())
    | Filter filter ->
      let%bind () =
        Video_db.get_videos db filter
        |> Pipe.iter_without_pushback ~f:print
        |> Deferred.ok
      in
      return ())
;;

let command =
  Command.async_or_error
    ~summary:"List videos according to filter."
    (let%map_open.Command () = return ()
     and dbpath = Params.dbpath
     and which_videos = Which_videos.param ~default:(Filter Filter.empty)
     and id =
       flag
         "-id"
         no_arg
         ~doc:" If passed, print just the video ID rather than all the video info"
     and json =
       flag "-json" no_arg ~doc:" If passed, print JSON objects instead of sexps"
     in
     fun () ->
       (* FIXME: This is no longer necessary, it is part of [Command.async_or_error] *)
       Writer.behave_nicely_in_pipeline ();
       if id && json then raise_s [%message "-id and -json cannot be used together"];
       main ~dbpath ~id ~json ~which_videos)
;;
