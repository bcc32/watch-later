open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let main dbpath ~download_dir =
  let deferreds = ref [] in
  let%bind db = Monitor.try_with_or_error (fun () -> Video_db.open_file_exn dbpath) in
  let%bind () =
    Monitor.try_with_or_error (fun () ->
      Video_db.iter_non_watched_videos_exn db ~f:(fun video ->
        deferreds := Download.download video ~base_dir:download_dir :: !deferreds;
        Deferred.return ()))
  in
  Deferred.Or_error.all_unit !deferreds
;;

let command =
  Command.async_or_error
    ~summary:"Download youtube videos from database"
    (let%map_open.Command.Let_syntax () = return ()
     and dbpath = Params.dbpath
     and download_dir =
       flag
         "download-dir"
         (required Filename.arg_type)
         ~doc:"DIR directory to store downloads in"
         ~aliases:[ "d" ]
     in
     fun () -> main dbpath ~download_dir)
;;
