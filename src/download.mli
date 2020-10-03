open! Core
open! Async
open! Import

val download : Video_info.t -> base_dir:string -> unit Or_error.t Deferred.t
