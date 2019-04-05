open! Core
open! Async
open! Import

let main dbpath ~download_dir =
  let deferreds = ref [] in
  let db = Db.open_file dbpath in
  Db.iter_non_watched_videos db ~f:(fun video ->
    deferreds := Download.download video ~base_dir:download_dir :: !deferreds);
  Deferred.all_unit !deferreds
;;

let command =
  Command.async
    ~summary:"Download youtube videos from database"
    (let%map_open.Command.Let_syntax () = return ()
     and dbpath = anon ("DBPATH" %: Filename.arg_type)
     and download_dir =
       flag
         "download-dir"
         (required Filename.arg_type)
         ~doc:"DIR directory to store downloads in"
         ~aliases:[ "d" ]
     in
     fun () -> main dbpath ~download_dir)
;;
