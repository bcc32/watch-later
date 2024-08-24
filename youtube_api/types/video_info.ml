open! Core
open! Import

type t =
  { channel_id : string
  ; channel_title : string
  ; video_id : Video_id.t
  ; video_title : string
  ; published_at : Time_ns.Alternate_sexp.t option
  ; duration : Time_ns.Span.t option
  }
[@@deriving fields, sexp_of]
