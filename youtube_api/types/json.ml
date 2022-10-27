open! Core
open! Import

type t = Jsonaf.t

let of_string = Jsonaf.of_string
let to_string = Jsonaf.to_string
let sexp_of_t = to_string >> [%sexp_of: string]

include Pretty_printer.Register_pp (struct
    type nonrec t = t

    let pp = Jsonaf.pp
    let module_name = "Youtube_api_types.Json"
  end)

let to_string_pretty t =
  pp Format.str_formatter t;
  Format.flush_str_formatter ()
;;
