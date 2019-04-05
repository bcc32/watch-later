open! Core
open! Async
open! Import

type t

(* TODO: Add function to close, or have something like [with_db_file]. *)

val open_file : string -> t
val iter_non_watched_videos : t -> f:(Video_info.t -> unit) -> unit
val video_stats : t -> Stats.t
