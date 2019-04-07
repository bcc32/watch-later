open! Core
open! Async
open! Import

type t

val open_file_exn : ?should_setup_schema:bool -> string -> t Deferred.t
val close : t -> unit Deferred.t

val with_file_exn
  :  ?should_setup_schema:bool
  -> string
  -> f:(t -> unit Deferred.t)
  -> unit Deferred.t

val iter_non_watched_videos_exn
  :  t
  -> f:(Video_info.t -> unit Deferred.t)
  -> unit Deferred.t

val video_stats_exn : t -> Stats.t Deferred.t
val add_video_exn : t -> Video_info.t -> overwrite:bool -> unit Deferred.t
val mark_watched : t -> Video_spec.t -> unit Deferred.t
val get_random_unwatched_video_exn : t -> Video_info.t Deferred.t
