open! Base
open Shexp_process
open Shexp_process.Let_syntax

let is_directory file =
  let%map stat = stat file in
  match stat.st_kind with
  | S_DIR -> true
  | S_REG | S_CHR | S_BLK | S_LNK | S_FIFO | S_SOCK -> false
;;

let list_migrations =
  readdir "."
  >>| Base.List.sort ~compare:String.compare
  >>= List.iter ~f:(fun dir ->
    if%bind is_directory dir
    then (
      let file = Caml.Filename.concat dir "up.sql" in
      if%bind file_exists file then printf "%s\n" file else return ())
    else return ())
;;

let cat file = stdin_from file read_all >>= print
let print_schema = print ".schema\n"

let sqlite =
  with_temp_file ~prefix:"empty-sqlite-init-file" ~suffix:"" (fun init_file ->
    run "sqlite3" [ "-init"; init_file; "-batch"; "-bail" ])
;;

let () = eval (list_migrations |- iter_lines cat >> print_schema |- sqlite)
