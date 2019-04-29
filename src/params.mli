open! Core
open! Async
open! Import

val dbpath : string Command.Param.t

(** Exactly one video specification. *)
val video : Video_spec.t Command.Param.t

(** Non-empty list of video specifications. *)
val videos : Video_spec.t list Command.Param.t
