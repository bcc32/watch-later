open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let main dbpath =
  let db = Db.open_file dbpath in
  let stats = Db.video_stats db in
  print_s [%sexp (stats : Stats.t)];
  return ()
;;

(* TODO: Stats by channel *)
let command =
  Command.async_or_error
    ~summary:"Show stats about the YouTube queue"
    (let%map_open.Command.Let_syntax () = return ()
     and dbpath = Params.dbpath in
     fun () -> main dbpath)
;;
