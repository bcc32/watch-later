open! Core
open! Async
open! Import
module Id : String_id.S

type t =
  { id : Id.t
  (** Identifies an item within a playlist; different from the
      video ID. *)
  ; video_id : Video_id.t
  }
[@@deriving fields, sexp_of]
