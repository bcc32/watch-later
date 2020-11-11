open! Core
open! Async
open! Import

let throttle = Throttle.create ~continue_on_error:false ~max_concurrent_jobs

let download (video : Video_info.t) ~base_dir =
  let working_dir = base_dir ^/ video.channel_id ^ "-" ^ video.channel_title in
  Throttle.enqueue throttle (fun () ->
    Async_interactive.Job.run !"downloading %{sexp:Video_info.t}" video ~f:(fun () ->
      let%bind () = Unix.mkdir ~p:() working_dir in
      let%map result =
        Process.run
          ()
          ~prog:"youtube-dl"
          ~args:[ "--"; Video_id.to_string video.video_id ]
          ~working_dir
      in
      let result = Or_error.ignore_m result in
      Or_error.tag_arg
        result
        "error downloading"
        (video, working_dir)
        [%sexp_of: Video_info.t * string]))
;;
