open! Core
open! Async
open! Import

type t

val with_file_and_txn
  :  string
  -> f:(t -> 'a Or_error.t Deferred.t)
  -> 'a Or_error.t Deferred.t

val video_stats : t -> Stats.t Or_error.t Deferred.t
val add_video : t -> Video_info.t -> overwrite:bool -> unit Or_error.t Deferred.t
val get : t -> Video_id.t -> (Video_info.t * bool) option Or_error.t Deferred.t
val mem : t -> Video_id.t -> bool Or_error.t Deferred.t

val mark_watched
  :  t
  -> Video_id.t
  -> [ `Watched | `Unwatched ]
  -> unit Or_error.t Deferred.t

val get_videos : t -> Filter.t -> (Video_info.t * bool) Pipe.Reader.t
val strict_remove : t -> Video_id.t -> [ `Ok | `Missing ] Or_error.t Deferred.t
