open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let main dbpath =
  let%bind db = Monitor.try_with_or_error (fun () -> Video_db.open_file_exn dbpath) in
  let%bind stats = Monitor.try_with_or_error (fun () -> Video_db.video_stats_exn db) in
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
