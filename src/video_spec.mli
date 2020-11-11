open! Core
open! Async
open! Import

type t [@@deriving sexp_of]

val of_video_id : Video_id.t -> t
val of_string : string -> t
val arg_type : t Command.Arg_type.t
val video_id : t -> Video_id.t
