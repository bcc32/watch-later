open! Core
open! Async
open! Import

(** [t] is an on-disk token source. *)
type t

(* FIXME: [token] to load fresh token. *)
val on_disk
  :  ?file:string (** Defaults to [Watch_later_directories.oauth_credentials_path] *)
  -> unit
  -> t Or_error.t Deferred.t

val of_json_save_to_disk
  :  ?file:string (** Defaults to [Watch_later_directories.oauth_credentials_path] *)
  -> Json.t
  -> client_id:string
  -> client_secret:string
  -> t Or_error.t Deferred.t

val access_token : t -> string Or_error.t Deferred.t
val is_expired : t -> bool
val refresh : t -> unit Or_error.t Deferred.t
