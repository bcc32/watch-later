open! Core
open! Async
open! Import

let command =
  Command.group
    ~summary:"Manage YouTube queue"
    [ "add", Cmd_add.command
    ; "debug", Cmd_debug.command
    ; "download", Cmd_download.command
    ; "mark-watched", Cmd_mark_watched.command
    ; "oauth", Cmd_oauth.command
    ; "stats", Cmd_stats.command
    ; "watch", Cmd_watch.command
    ]
;;
