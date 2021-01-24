open! Core
open! Async
open! Import

let command =
  Command.group
    ~summary:"Manage YouTube queue"
    [ "add", Cmd_add.command
    ; "debug", Cmd_debug.command
    ; "download", Cmd_download.command
    ; "list", Cmd_list.command
    ; "mark-watched", Cmd_mark_watched.command
    ; "oauth", Cmd_oauth.command
    ; "playlist", Cmd_playlist.command
    ; "stats", Cmd_stats.command
    ; "watch", Cmd_watch.command
    ]
;;
