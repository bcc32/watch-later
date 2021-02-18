open! Core
open! Async
open! Import

module Print_path = struct
  let command =
    Command.async_or_error
      ~summary:"Print file path to database"
      (let%map_open.Command () = return ()
       and dbpath = Params.dbpath in
       fun () ->
         print_endline dbpath;
         return ())
  ;;
end

let command =
  Command.group ~summary:"Database debugging commands" [ "path", Print_path.command ]
;;
