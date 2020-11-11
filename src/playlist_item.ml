open! Core
open! Async
open! Import

type t =
  { id : string
  ; video_id : Video_id.t
  }
[@@deriving fields, sexp_of]
