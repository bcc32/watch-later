open! Core
open! Async

let iter_non_watched_videos db ~f =
  match
    Sqlite3.exec_not_null_no_headers
      db
      {|
SELECT channel_id, channel_title, video_id, video_title
FROM videos
WHERE NOT watched;
|}
      ~cb:(fun row ->
        match row with
        | [| channel_id; channel_title; video_id; video_title |] ->
          f ~channel_id ~channel_title ~video_id ~video_title
        | _ -> raise_s [%message "wrong number of fields" (row : string array)])
  with
  | Sqlite3.Rc.OK -> ()
  | rc -> print_s [%message "non-OK rc" (Sqlite3.Rc.to_string rc : string)]
;;

let max_concurrent_jobs =
  match Linux_ext.cores with
  | Ok f -> f ()
  | Error _ -> 4
;;

let main dbpath =
  let db = Sqlite3.db_open ~mode:`READONLY dbpath in
  let deferreds = ref [] in
  let throttle = Throttle.create ~continue_on_error:true ~max_concurrent_jobs in
  let download ~channel_id ~channel_title ~video_id ~video_title =
    let working_dir = "download" ^/ channel_id ^ "-" ^ channel_title in
    let f () =
      let%bind () = Unix.mkdir ~p:() working_dir in
      Log.Global.sexp
        ~level:`Info
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
        Log.Global.sexp
          ~level:`Info
          [%message
            "done downloading"
              (video_title : string)
              (channel_title : string)
              (video_id : string)
              (working_dir : string)]
      | Error e ->
        Log.Global.sexp
          ~level:`Error
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
  iter_non_watched_videos db ~f:download;
  Deferred.all_unit !deferreds
;;

let command =
  Command.async
    ~summary:"Download youtube videos from database"
    (let open Command.Let_syntax in
     let%map_open () = return ()
     and dbpath = anon ("DBPATH" %: Filename.arg_type) in
     fun () -> main dbpath)
;;

let () = Command.run command
