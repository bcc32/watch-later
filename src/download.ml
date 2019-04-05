open! Core
open! Async
open! Import

let throttle = Throttle.create ~continue_on_error:false ~max_concurrent_jobs

let download (video : Video_info.t) ~base_dir =
  let working_dir = base_dir ^/ video.channel_id ^ "-" ^ video.channel_title in
  Throttle.enqueue throttle (fun () ->
    Async_interactive.Job.run !"downloading %{sexp:Video_info.t}" video ~f:(fun () ->
      let%bind () = Unix.mkdir ~p:() working_dir in
      match%map
        Process.run () ~prog:"youtube-dl" ~args:[ "--"; video.video_id ] ~working_dir
      with
      | Ok _ -> ()
      | Error e ->
        Log.Global.error_s
          [%message
            "error downloading"
              (e : Error.t)
              (video : Video_info.t)
              (working_dir : string)]))
;;
