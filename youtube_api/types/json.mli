open! Core
open! Import

(** JSON values.

    [sexp_of_t] is just an atom of the JSON string. *)
type t = Jsonaf.t [@@deriving sexp_of]

include Stringable with type t := t
include Pretty_printer.S with type t := t

val to_string_pretty : t -> string
