open! Core_kernel
open! Import
include String_id.S

module Plain_or_in_url : sig
  val of_string : string -> t
  val arg_type : t Command.Arg_type.t
end

include Of_jsonable.S with type t := t
