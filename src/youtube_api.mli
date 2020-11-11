open! Core
open! Async
open! Import

module Credentials : sig
  type t =
    [ `Access_token of string
    | `Api_key of string
    ]

  val param : t Command.Param.t
end

type t

val create : Credentials.t -> t

val call
  :  ?accept_status:(Cohttp.Code.status_code -> bool)
  -> t
  -> method_:Cohttp.Code.meth
  -> endpoint:string
  -> params:(string, string) List.Assoc.t
  -> string Or_error.t Deferred.t

val get_video_info : t -> Video_spec.t -> Video_info.t Or_error.t Deferred.t

(** See https://developers.google.com/youtube/v3/docs/videos/list for the
    documentation of [parts]. *)
val get_video_json
  :  t
  -> Video_spec.t
  -> parts:string list
  -> Yojson.Basic.t Or_error.t Deferred.t

val get_playlist_items : t -> Playlist_id.t -> Playlist_item.t list Or_error.t Deferred.t
val clear_playlist : t -> Playlist_id.t -> unit Or_error.t Deferred.t
