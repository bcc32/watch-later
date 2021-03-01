open! Core
open! Async
open! Import

type t

val param : default_to_unwatched:bool -> t Command.Param.t
val is_empty : t -> bool
val t : t Caqti_type.t
