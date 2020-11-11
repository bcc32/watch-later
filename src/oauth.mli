open! Core
open! Async
open! Import

type t =
  { client_id : string
  ; client_secret : string
  ; access_token : string
  ; refresh_token : string
  ; expiry : Time_ns.t
  }
[@@deriving sexp]

val load : unit -> t Or_error.t Deferred.t
val save : t -> unit Or_error.t Deferred.t
val refresh_and_save : t -> [ `Force | `If_expired ] -> t Or_error.t Deferred.t
