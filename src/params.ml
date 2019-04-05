open! Core
open! Async
open! Import

(* TODO: Make this a flag, and default to environment variable or a fixed path. *)
let dbpath = Command.Param.anon Command.Anons.("DBPATH" %: Filename.arg_type)
