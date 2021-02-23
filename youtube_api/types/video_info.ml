open! Core_kernel
open! Import

type t =
  { channel_id : string
  ; channel_title : string
  ; video_id : Video_id.t
  ; video_title : string
  }
[@@deriving fields, sexp_of]
