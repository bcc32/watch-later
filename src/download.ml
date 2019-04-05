open! Core
open! Async
open! Import

let throttle = Throttle.create ~continue_on_error:false ~max_concurrent_jobs

let download (video : Video.t) =
  let working_dir = video.channel_id ^ "-" ^ video.channel_title in
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
  Throttle.enqueue throttle f
;;
