open! Core
open! Async
open! Import

let dbpath =
  let%map_open.Command.Let_syntax () = return ()
  and path =
    flag
      "dbpath"
      (optional Filename.arg_type)
      ~doc:
        "FILE path to database file (default is $WATCH_LATER_DBPATH or \
         $HOME/watch-later.db)"
  in
  match path with
  | Some path -> path
  | None ->
    (match Sys.getenv "WATCH_LATER_DBPATH" with
     | Some path -> path
     | None -> Sys.getenv_exn "HOME" ^/ "watch-later.db")
;;
