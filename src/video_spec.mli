open! Core
open! Async
open! Import

type t

val of_video_id : string -> t
val of_string : string -> t
val arg_type : t Command.Arg_type.t
val video_id : t -> string
