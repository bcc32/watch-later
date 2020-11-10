open! Core
open! Async
open! Import

let valid_code_verifier_chars =
  lazy
    (Array.init 256 ~f:Char.of_int_exn
     |> Array.filter ~f:(function
       | 'A' .. 'Z' -> true
       | 'a' .. 'z' -> true
       | '0' .. '9' -> true
       | '-' | '.' | '_' | '~' -> true
       | _ -> false))
;;

let code_challenge =
  let to_base64url = String.tr_multi ~target:"+/" ~replacement:"-_" |> unstage in
  fun ~code_verifier ->
    code_verifier
    |> Cryptokit.hash_string (Cryptokit.Hash.sha256 ())
    |> Cryptokit.transform_string (Cryptokit.Base64.encode_compact ())
    |> to_base64url
;;

(* Based on https://developers.google.com/youtube/v3/guides/auth/installed-apps *)
let obtain_access_token ~client_id ~client_secret =
  (* FIXME: Not cryptographically secure *)
  let code_verifier =
    String.init 128 ~f:(fun _ ->
      Array.random_element_exn (force valid_code_verifier_chars))
  in
  let code_challenge = code_challenge ~code_verifier in
  let endpoint =
    Uri.make
      ~scheme:"https"
      ~host:"accounts.google.com"
      ~path:"/o/oauth2/v2/auth"
      ~query:
        [ "client_id", [ client_id ]
        ; "redirect_uri", [ "urn:ietf:wg:oauth:2.0:oob" ] (* Manual copy/paste *)
        ; "response_type", [ "code" ]
        ; "scope", [ "https://www.googleapis.com/auth/youtube.force-ssl" ]
        ; "code_challenge", [ code_challenge ]
        ; "code_challenge_method", [ "S256" ]
        ]
      ()
  in
  Browse.url endpoint |> ok_exn;
  let%bind authorization_code =
    Async_interactive.ask_dispatch_gen "Authorization Code" ~f:(fun code ->
      if String.is_empty code then Error "Empty code" else Ok code)
  in
  let token_endpoint =
    Uri.make ~scheme:"https" ~host:"oauth2.googleapis.com" ~path:"/token" ()
  in
  let%bind response, body =
    Cohttp_async.Client.post_form
      token_endpoint
      ~params:
        [ "client_id", [ client_id ]
        ; "client_secret", [ client_secret ]
        ; "code", [ authorization_code ]
        ; "code_verifier", [ code_verifier ]
        ; "grant_type", [ "authorization_code" ]
        ; "redirect_uri", [ "urn:ietf:wg:oauth:2.0:oob" ]
        ]
  in
  if response.status |> Cohttp.Code.code_of_status |> Cohttp.Code.is_success
  then (
    let%bind body = Cohttp_async.Body.to_string body in
    print_endline body;
    return ())
  else
    raise_s
      [%message
        "Failed to obtain access token"
          ~status:(response.status : Cohttp.Code.status_code)]
;;

let command =
  Command.async
    ~summary:"Generate valid OAuth 2.0 token for YouTube Data API"
    (let%map_open.Command () = return ()
     and client_id = flag "client-id" (required string) ~doc:"STRING OAuth Client ID"
     and client_secret =
       flag "client-secret" (required string) ~doc:"STRING OAuth Client Secret"
     in
     fun () -> obtain_access_token ~client_id ~client_secret)
;;
