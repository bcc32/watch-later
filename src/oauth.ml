open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

type t =
  { access_token : string
  ; refresh_token : string
  }
[@@deriving sexp]

let cred_file () =
  let%map config_path =
    match Sys.getenv "XDG_CONFIG_HOME" with
    | Some config_path -> return config_path
    | None ->
      (match Sys.getenv "HOME" with
       | Some home -> return (home ^/ ".config")
       | None ->
         Deferred.Or_error.error_s [%message "Neither XDG_CONFIG_HOME nor HOME set"])
  in
  config_path ^/ "watch-later" ^/ "credentials"
;;

let load () =
  let%bind cred_file = cred_file () in
  Reader.load_sexp cred_file [%of_sexp: t]
;;

let save t =
  let%bind cred_file = cred_file () in
  let%bind () =
    Monitor.try_with_or_error (fun () -> Unix.mkdir ~p:() (Filename.dirname cred_file))
  in
  let%bind () =
    Monitor.try_with_or_error (fun () ->
      Writer.save_sexp ~perm:0o600 cred_file [%sexp (t : t)])
  in
  return ()
;;
