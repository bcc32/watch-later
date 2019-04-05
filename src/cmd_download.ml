open! Core
open! Async
open! Import

let main dbpath =
  let deferreds = ref [] in
  let db = Db.open_file dbpath in
  Db.iter_non_watched_videos db ~f:(fun video ->
    deferreds := Download.download video :: !deferreds);
  Deferred.all_unit !deferreds
;;

let command =
  Command.async
    ~summary:"Download youtube videos from database"
    (let%map_open.Command.Let_syntax () = return ()
     and dbpath = anon ("DBPATH" %: Filename.arg_type) in
     fun () -> main dbpath)
;;
