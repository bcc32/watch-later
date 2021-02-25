open! Core_kernel
open! Import
include Yojson.Basic

let of_string s = from_string s
let to_string s = to_string s
let sexp_of_t = to_string >> [%sexp_of: string]

include Pretty_printer.Register_pp (struct
    type nonrec t = t

    let pp = Yojson.Basic.pretty_print ~std:true
    let module_name = "Youtube_api_types.Json"
  end)

let to_string_pretty t =
  pp Format.str_formatter t;
  Format.flush_str_formatter ()
;;
