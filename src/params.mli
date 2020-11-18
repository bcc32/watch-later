open! Core
open! Async
open! Import

val dbpath : string Command.Param.t

(** Exactly one video ID. *)
val video : Video_id.t Command.Param.t

(** List of video IDs.  May be empty. *)
val videos : Video_id.t list Command.Param.t

(** Non-empty list of video IDs. *)
val nonempty_videos : Video_id.t list Command.Param.t

val filter : Video_db.Filter.t Command.Param.t
