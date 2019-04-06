open! Core
open! Async
open! Import

type t

val of_string : string -> t
val video_id : t -> string
