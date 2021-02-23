open! Core
open! Async
open! Import
module Video_info = Video_info

type t

val command
  :  ?extract_exn:bool
  -> summary:string
  -> ?readme:(unit -> string)
  -> (t -> unit Or_error.t Deferred.t) Command.Param.t
  -> Command.t

val call
  :  ?accept_status:(Cohttp.Code.status_code -> bool)
  -> ?body:Yojson.Basic.t
  -> t
  -> method_:Cohttp.Code.meth
  -> endpoint:string
  -> params:(string, string) List.Assoc.t
  -> string Or_error.t Deferred.t

val get_video_info : t -> Video_id.t -> Video_info.t Or_error.t Deferred.t

val get_video_info'
  :  t
  -> Video_id.t Pipe.Reader.t
  -> Video_info.t Or_error.t Pipe.Reader.t

(** See https://developers.google.com/youtube/v3/docs/videos/list for the
    documentation of [parts]. *)
val get_video_json'
  :  t
  -> Video_id.t Pipe.Reader.t
  -> parts:string list
  -> Yojson.Basic.t Or_error.t Pipe.Reader.t

val get_playlist_items : t -> Playlist_id.t -> Playlist_item.t list Or_error.t Deferred.t
val delete_playlist_item : t -> Playlist_item.Id.t -> unit Or_error.t Deferred.t

val append_video_to_playlist
  :  t
  -> Playlist_id.t
  -> Video_id.t
  -> unit Or_error.t Deferred.t
