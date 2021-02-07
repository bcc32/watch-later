open! Core
open! Async
open! Import

type t

val create : unit -> t Or_error.t Deferred.t

val call
  :  ?accept_status:(Cohttp.Code.status_code -> bool)
  -> ?body:Yojson.Basic.t
  -> t
  -> method_:Cohttp.Code.meth
  -> endpoint:string
  -> params:(string, string) List.Assoc.t
  -> string Or_error.t Deferred.t

val get_video_info : t -> Video_id.t -> Video_info.t Or_error.t Deferred.t

(** See https://developers.google.com/youtube/v3/docs/videos/list for the
    documentation of [parts]. *)
val get_video_json
  :  t
  -> Video_id.t
  -> parts:string list
  -> Yojson.Basic.t Or_error.t Deferred.t

val get_playlist_items
  :  ?video_id:Video_id.t
  -> t
  -> Playlist_id.t
  -> Playlist_item.t list Or_error.t Deferred.t

(* FIXME: Add module for Playlist_item_id *)
val delete_playlist_item
  :  t
  -> string (** playlist item ID *)
  -> unit Or_error.t Deferred.t

val append_video_to_playlist
  :  t
  -> Playlist_id.t
  -> Video_id.t
  -> unit Or_error.t Deferred.t
