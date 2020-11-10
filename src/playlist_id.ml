open! Core
open! Async
open! Import

include String_id.Make
    (struct
      let module_name = "Watch_later.Playlist_id"
    end)
    ()

let arg_type = Command.Arg_type.create of_string
