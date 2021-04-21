open! Core
open! Async
open! Import

let () = Log.Global.set_output [ Log.Output.stderr ~format:`Sexp_hum () ]
let () = Command.run Watch_later.command
