open! Core
open! Async
open! Import

type t [@@deriving sexp_of]

val of_string : string -> t
val video_id : t -> Video_id.t
