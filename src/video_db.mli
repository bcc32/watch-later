open! Core
open! Async
open! Import

type t

val open_file : ?should_setup_schema:bool -> string -> t Deferred.Or_error.t
val close : t -> unit Deferred.Or_error.t

val with_file
  :  ?should_setup_schema:bool
  -> string
  -> f:(t -> 'a Deferred.Or_error.t)
  -> 'a Deferred.Or_error.t

val iter_non_watched_videos
  :  t
  -> f:(Video_info.t -> unit Deferred.t)
  -> unit Deferred.Or_error.t

val video_stats : t -> Stats.t Deferred.Or_error.t
val add_video : t -> Video_info.t -> overwrite:bool -> unit Deferred.Or_error.t
val mark_watched : t -> Video_spec.t -> unit Deferred.Or_error.t
val get_random_unwatched_video : t -> Video_info.t Deferred.Or_error.t
