open! Core
open! Async
open! Import

(* FIXME: This type is not exposed, but [Video_db] depends on its field order. *)
type t

val empty : t
val unwatched : t
val param : t Command.Param.t
val is_empty : t -> bool
val t : t Caqti_type.t
