open! Core_kernel
open! Import

module type S = sig
  type t

  val of_json : Yojson.Basic.t -> t
end
