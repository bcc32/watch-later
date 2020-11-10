open! Core
open! Async
open! Import

type t =
  { access_token : string
  ; refresh_token : string
  }
[@@deriving sexp]

val load : unit -> t Or_error.t Deferred.t
val save : t -> unit Or_error.t Deferred.t
