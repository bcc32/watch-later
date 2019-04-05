open! Core
open! Async
open! Import

let main dbpath =
  let deferreds = ref [] in
  let download (video : Video.t) =
    let working_dir = "download" ^/ video.channel_id ^ "-" ^ video.channel_title in
    let f () =
      Async_interactive.Job.run !"downloading %{sexp:Video.t}" video ~f:(fun () ->
        let%bind () = Unix.mkdir ~p:() working_dir in
        match%map
          Process.run () ~prog:"youtube-dl" ~args:[ "--"; video.video_id ] ~working_dir
        with
        | Ok _ -> ()
        | Error e ->
          Log.Global.error_s
            [%message
              "error downloading" (e : Error.t) (video : Video.t) (working_dir : string)])
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
