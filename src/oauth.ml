open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

type t =
  { client_id : string
  ; client_secret : string
  ; access_token : string
  ; refresh_token : string
  ; expiry : Time_ns.t
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

let refresh { client_id; client_secret; access_token = _; refresh_token; expiry = _ } =
  let endpoint =
    Uri.make ~scheme:"https" ~host:"oauth2.googleapis.com" ~path:"/token" ()
  in
  let%bind response, body =
    Monitor.try_with_or_error (fun () ->
      Cohttp_async.Client.post_form
        endpoint
        ~params:
          [ "client_id", [ client_id ]
          ; "client_secret", [ client_secret ]
          ; "grant_type", [ "refresh_token" ]
          ; "refresh_token", [ refresh_token ]
          ])
  in
  if response.status |> Cohttp.Code.code_of_status |> Cohttp.Code.is_success
  then (
    let%bind body = Cohttp_async.Body.to_string body |> Deferred.ok in
    let%bind access_token, expiry =
      Or_error.try_with (fun () ->
        let json = Yojson.Basic.from_string body in
        let open Yojson.Basic.Util in
        let access_token = json |> member "access_token" |> to_string in
        let expires_in = json |> member "expires_in" |> to_int in
        access_token, Time_ns.add (Time_ns.now ()) (Time_ns.Span.of_int_sec expires_in))
      |> Deferred.return
    in
    return { client_id; client_secret; access_token; refresh_token; expiry })
  else
    Deferred.Or_error.error_s
      [%message
        "Failed to refresh access token"
          ~status:(Cohttp.Code.string_of_status response.status)]
;;

let perform_refresh_and_save t =
  let%bind t = refresh t in
  let%bind () = save t in
  return t
;;

let refresh_and_save t when_ =
  match when_ with
  | `Force -> perform_refresh_and_save t
  | `If_expired ->
    if Time_ns.is_earlier (Time_ns.now ()) ~than:t.expiry
    then return t
    else perform_refresh_and_save t
;;
