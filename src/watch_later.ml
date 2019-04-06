open! Core
open! Async
open! Import

let command =
  Command.group
    ~summary:"Manage YouTube queue"
    [ "debug", Cmd_debug.command
    ; "download", Cmd_download.command
    ; "stats", Cmd_stats.command
    ]
;;
