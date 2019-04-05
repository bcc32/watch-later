open! Core
open! Async
open! Import

type t

val open_file_exn : ?should_setup_schema:bool -> string -> t
val close : t -> unit Deferred.t

val with_file_exn
  :  ?should_setup_schema:bool
  -> string
  -> f:(t -> unit Deferred.t)
  -> unit Deferred.t

val iter_non_watched_videos_exn : t -> f:(Video_info.t -> unit) -> unit
val video_stats_exn : t -> Stats.t
val add_video_overwrite_exn : t -> Video_info.t -> unit
