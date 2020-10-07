open! Core
open! Async
open! Import

type t

val open_file : ?should_setup_schema:bool -> string -> t Or_error.t Deferred.t
val close : t -> unit Or_error.t Deferred.t

val with_file
  :  ?should_setup_schema:bool
  -> string
  -> f:(t -> 'a Or_error.t Deferred.t)
  -> 'a Or_error.t Deferred.t

val iter_non_watched_videos
  :  t
  -> f:(Video_info.t -> unit Deferred.t)
  -> unit Or_error.t Deferred.t

val video_stats : t -> Stats.t Or_error.t Deferred.t

val add_video
  :  t
  -> Video_info.t
  -> mark_watched:[ `Watched | `Unwatched ] option
  -> overwrite:bool
  -> unit Or_error.t Deferred.t

val mark_watched
  :  t
  -> Video_spec.t
  -> [ `Watched | `Unwatched ]
  -> unit Or_error.t Deferred.t

val get_random_unwatched_video : t -> Video_info.t Or_error.t Deferred.t
