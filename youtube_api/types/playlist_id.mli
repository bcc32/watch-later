open! Core_kernel
open! Import
include String_id.S

module Plain_or_in_url : sig
  val of_string : string -> t
  val arg_type : t Command.Arg_type.t
end

val of_json : t Of_json.t
