open! Core_kernel
open! Import

module Id =
  String_id.Make
    (struct
      let module_name = "Watch_later.Playlist_item.Id"
    end)
    ()

type t =
  { id : Id.t
  ; video_id : Video_id.t
  }
[@@deriving fields, sexp_of]
