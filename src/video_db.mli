open! Core
open! Async
open! Import

type t

val with_file
  :  ?should_setup_schema:bool
  -> string
  -> f:(t -> 'a Or_error.t Deferred.t)
  -> 'a Or_error.t Deferred.t

val iter_non_watched_videos
  :  t
  -> f:(Video_info.t -> unit Or_error.t Deferred.t)
  -> unit Or_error.t Deferred.t

val video_stats : t -> Stats.t Or_error.t Deferred.t

val add_video
  :  t
  -> Video_info.t
  -> mark_watched:[ `Watched | `Unwatched ] option
  -> overwrite:bool
  -> unit Or_error.t Deferred.t

val mem : t -> Video_id.t -> bool Or_error.t Deferred.t

val mark_watched
  :  t
  -> Video_id.t
  -> [ `Watched | `Unwatched ]
  -> unit Or_error.t Deferred.t

module Filter : sig
  type t =
    { video_id : string option
    ; video_title : string option
    ; channel_id : string option
    ; channel_title : string option
    }

  val is_empty : t -> bool
end

val get_random_unwatched_video : t -> Filter.t -> Video_info.t Or_error.t Deferred.t
