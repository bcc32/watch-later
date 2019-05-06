open! Core
open! Async
open! Import

val dbpath : string Command.Param.t

(** Exactly one video specification. *)
val video : Video_spec.t Command.Param.t

(** List of video specifications.  May be empty. *)
val videos : Video_spec.t list Command.Param.t

(** Non-empty list of video specifications. *)
val nonempty_videos : Video_spec.t list Command.Param.t
