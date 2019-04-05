open! Core
open! Async
open! Import

let command =
  Command.group ~summary:"Manage YouTube queue" [ "download", Cmd_download.command ]
;;
