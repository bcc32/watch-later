open! Core
open! Async
open! Import

let max_concurrent_jobs =
  match Linux_ext.cores with
  | Ok f -> f ()
  | Error _ -> 4
;;

let main dbpath =
  let deferreds = ref [] in
  let throttle = Throttle.create ~continue_on_error:true ~max_concurrent_jobs in
  let download { Video.channel_id; channel_title; video_id; video_title } =
    let working_dir = "download" ^/ channel_id ^ "-" ^ channel_title in
    let f () =
      let%bind () = Unix.mkdir ~p:() working_dir in
      Log.Global.info_s
        [%message
          "downloading video"
            (video_title : string)
            (channel_title : string)
            (video_id : string)
            (working_dir : string)];
      match%map
        Process.run () ~prog:"youtube-dl" ~args:[ "--"; video_id ] ~working_dir
      with
      | Ok _ ->
        Log.Global.info_s
          [%message
            "done downloading"
              (video_title : string)
              (channel_title : string)
              (video_id : string)
              (working_dir : string)]
      | Error e ->
        Log.Global.error_s
          [%message
            "error downloading"
              (e : Error.t)
              (video_title : string)
              (channel_title : string)
              (video_id : string)
              (working_dir : string)]
    in
    deferreds := Throttle.enqueue throttle f :: !deferreds
  in
  let db = Db.open_file dbpath in
  Db.iter_non_watched_videos db ~f:download;
  Deferred.all_unit !deferreds
;;

let command =
  Command.async
    ~summary:"Download youtube videos from database"
    (let%map_open.Command.Let_syntax () = return ()
     and dbpath = anon ("DBPATH" %: Filename.arg_type) in
     fun () -> main dbpath)
;;
