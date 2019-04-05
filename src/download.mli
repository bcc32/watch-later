open! Core
open! Async
open! Import

val download : Video_info.t -> base_dir:string -> unit Deferred.Or_error.t
