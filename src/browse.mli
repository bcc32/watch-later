open! Core
open! Async
open! Import

val url : Uri.t -> unit Or_error.t Deferred.t
