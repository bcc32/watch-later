(** An entry in a YouTube playlist, which usually contains a video.

    @see <https://developers.google.com/youtube/v3/docs/playlistItems> *)

open! Core_kernel
open! Import
module Id : String_id.S

type t [@@deriving sexp_of]

include Of_jsonable.S with type t := t

(** Identifies an item within a playlist; different from the video ID. *)
val id : t -> Id.t

val video_id : t -> Video_id.t
val video_info : t -> Video_info.t
