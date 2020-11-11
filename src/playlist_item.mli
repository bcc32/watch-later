open! Core
open! Async
open! Import

type t =
  { id : string
  (** Identifies an item within a playlist; different from the
      video ID. *)
  ; video_id : Video_id.t
  }
[@@deriving fields, sexp_of]
