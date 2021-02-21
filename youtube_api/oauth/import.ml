open! Core
open! Async
include Composition_infix
include Ppx_log_async
include Deferred.Or_error.Let_syntax

let () = Log.Global.set_output [ Log.Output.stderr ~format:`Sexp_hum () ]
