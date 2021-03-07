open! Core
open! Async
open! Import

type t =
  { client_id : string
  ; client_secret : string
  ; access_token : string
  ; refresh_token : string
  ; expiry : Time_ns.t
  }
[@@deriving sexp]

let cred_file = Watch_later_directories.oauth_credentials_path
let load () = Reader.load_sexp cred_file [%of_sexp: t]

let save t =
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
    let%bind json = Cohttp_async.Body.to_string body |> Deferred.ok in
    let%bind json = Deferred.return (Or_error.try_with (fun () -> Json.of_string json)) in
    let%bind access_token, expiry =
      (* FIXME: This code is similar to [cmd_oauth]. *)
      Of_json.run
        json
        (let%map_open.Of_json access_token = "access_token" @. string
         and expires_in = "expires_in" @. int >>| Time_ns.Span.of_int_sec in
         access_token, Time_ns.add (Time_ns.now ()) expires_in)
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

let expiry_delta = Time_ns.Span.of_int_sec 10

let is_expired t =
  Time_ns.is_earlier (Time_ns.sub t.expiry expiry_delta) ~than:(Time_ns.now ())
;;

let refresh_and_save t when_ =
  match when_ with
  | `Force -> perform_refresh_and_save t
  | `If_expired -> if is_expired t then perform_refresh_and_save t else return t
;;

let load_fresh ?(force_refresh = false) () =
  let when_ = if force_refresh then `Force else `If_expired in
  load () >>= Fn.flip refresh_and_save when_
;;
