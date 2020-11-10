open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

(* TODO: Store auth token in ~/.cache. *)

let rec fill_random_bytes (rng : Cryptokit.Random.rng) bytes ~pos ~len ~byte_is_acceptable
  =
  if len <= 0
  then ()
  else (
    rng#random_bytes bytes pos len;
    let rec keep_acceptable_bytes ~src_pos ~dst_pos =
      if src_pos >= Bytes.length bytes
      then
        fill_random_bytes
          rng
          bytes
          ~pos:dst_pos
          ~len:(len - (dst_pos - pos))
          ~byte_is_acceptable
      else if byte_is_acceptable (Bytes.get bytes src_pos)
      then (
        Bytes.set bytes dst_pos (Bytes.get bytes src_pos);
        keep_acceptable_bytes ~src_pos:(src_pos + 1) ~dst_pos:(dst_pos + 1))
      else keep_acceptable_bytes ~src_pos:(src_pos + 1) ~dst_pos
    in
    keep_acceptable_bytes ~src_pos:pos ~dst_pos:pos)
;;

let is_valid_code_verifier_char = function
  | 'A' .. 'Z' -> true
  | 'a' .. 'z' -> true
  | '0' .. '9' -> true
  | '-' | '.' | '_' | '~' -> true
  | _ -> false
;;

let generate_code_verifier_and_challenge =
  let rng =
    Cryptokit.Random.pseudo_rng (Cryptokit.Random.string Cryptokit.Random.secure_rng 20)
  in
  let to_base64url = String.tr_multi ~target:"+/" ~replacement:"-_" |> unstage in
  fun () ->
    let buf = Bytes.create 128 in
    fill_random_bytes
      rng
      buf
      ~pos:0
      ~len:128
      ~byte_is_acceptable:is_valid_code_verifier_char;
    let verifier = Bytes.unsafe_to_string ~no_mutation_while_string_reachable:buf in
    let challenge =
      verifier
      |> Cryptokit.hash_string (Cryptokit.Hash.sha256 ())
      |> Cryptokit.transform_string (Cryptokit.Base64.encode_compact ())
      |> to_base64url
    in
    verifier, challenge
;;

(* Based on https://developers.google.com/youtube/v3/guides/auth/installed-apps *)
let obtain_access_token ~client_id ~client_secret =
  let code_verifier, code_challenge = generate_code_verifier_and_challenge () in
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
    Monitor.try_with_or_error (fun () ->
      Async_interactive.ask_dispatch_gen "Authorization Code" ~f:(fun code ->
        if String.is_empty code then Error "Empty code" else Ok code))
  in
  let token_endpoint =
    Uri.make ~scheme:"https" ~host:"oauth2.googleapis.com" ~path:"/token" ()
  in
  let%bind response, body =
    Monitor.try_with_or_error (fun () ->
      Cohttp_async.Client.post_form
        token_endpoint
        ~params:
          [ "client_id", [ client_id ]
          ; "client_secret", [ client_secret ]
          ; "code", [ authorization_code ]
          ; "code_verifier", [ code_verifier ]
          ; "grant_type", [ "authorization_code" ]
          ; "redirect_uri", [ "urn:ietf:wg:oauth:2.0:oob" ]
          ])
  in
  if response.status |> Cohttp.Code.code_of_status |> Cohttp.Code.is_success
  then (
    let%bind body = Cohttp_async.Body.to_string body |> Deferred.ok in
    print_endline body;
    return ())
  else
    raise_s
      [%message
        "Failed to obtain access token"
          ~status:(response.status : Cohttp.Code.status_code)]
;;

let command =
  Command.async_or_error
    ~summary:"Generate valid OAuth 2.0 token for YouTube Data API"
    (let%map_open.Command () = return ()
     and client_id = flag "client-id" (required string) ~doc:"STRING OAuth Client ID"
     and client_secret =
       flag "client-secret" (required string) ~doc:"STRING OAuth Client Secret"
     in
     fun () -> obtain_access_token ~client_id ~client_secret)
;;
