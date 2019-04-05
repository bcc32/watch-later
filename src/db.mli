open! Core
open! Async
open! Import

type t

val open_file : string -> t
val iter_non_watched_videos : t -> f:(Video_info.t -> unit) -> unit
