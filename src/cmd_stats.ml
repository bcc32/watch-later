open! Core
open! Async
open! Import

let main dbpath =
  Video_db.with_file dbpath ~f:(fun db ->
    let%bind stats = Video_db.video_stats db in
    print_s [%sexp (stats : Stats.t)];
    return ())
;;

(* TODO: Stats by channel *)
let command =
  Command.async_or_error
    ~summary:"Show stats about the YouTube queue"
    (let%map_open.Command () = return ()
     and dbpath = Params.dbpath in
     fun () -> main dbpath)
;;
