open! Core
open! Async
open! Import

type t =
  { channel_id : string
  ; channel_title : string
  ; video_id : string
  ; video_title : string
  }
[@@deriving sexp_of]
