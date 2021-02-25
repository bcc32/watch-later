open! Core_kernel
open! Import

type t =
  [ `Assoc of (string * t) list
  | `Bool of bool
  | `Float of float
  | `Int of int
  | `List of t list
  | `Null
  | `String of string
  ]
[@@deriving sexp_of]

include Stringable with type t := t

include module type of struct
  include Yojson.Basic
end
with type t := t
