open! Core
open! Async
open! Import

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
    lazy
      (Cryptokit.Random.pseudo_rng
         (Cryptokit.Random.string Cryptokit.Random.secure_rng 20))
  in
  let to_base64url = String.tr_multi ~target:"+/" ~replacement:"-_" |> unstage in
  fun () ->
    let buf = Bytes.create 128 in
    fill_random_bytes
      (force rng)
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

(* TODO: Move this logic into oauth.ml *)

let listen_for_authorization_code_response () =
  let authorization_code = Ivar.create () in
  let%map server =
    Monitor.try_with_or_error (fun () ->
      Cohttp_async.Server.create
        ~on_handler_error:`Raise
        Tcp.Where_to_listen.of_port_chosen_by_os
        (fun ~body:_ _addr request ->
           let uri = Cohttp.Request.uri request in
           let result =
             match Uri.get_query_param uri "error" with
             | Some error ->
               Or_error.error_s [%message "Failed to get access token" (error : string)]
             | None ->
               (match Uri.get_query_param uri "code" with
                | Some code -> Ok code
                | None -> raise_s [%message "Response contained neither error nor code"])
           in
           Ivar.fill authorization_code result;
           match result with
           | Ok _ ->
             Cohttp_async.Server.respond_string
               "Successfully authorized.  You can now close this tab and return to the \
                command line."
           | Error error ->
             Cohttp_async.Server.respond_string
               ~status:`Unauthorized
               (Error.to_string_hum
                  (Error.tag ~tag:"Failed to authorize with YouTube API." error))))
  in
  let port = Cohttp_async.Server.listening_on server in
  port, Ivar.read authorization_code
;;

(* Based on
   https://developers.google.com/youtube/v3/guides/auth/installed-apps *)
let obtain_access_token_and_save ~client_id ~client_secret =
  let code_verifier, code_challenge = generate_code_verifier_and_challenge () in
  let%bind listening_port, authorization_code_deferred =
    listen_for_authorization_code_response ()
  in
  let redirect_uri = sprintf "http://127.0.0.1:%d" listening_port in
  let endpoint =
    Uri.make
      ~scheme:"https"
      ~host:"accounts.google.com"
      ~path:"/o/oauth2/v2/auth"
      ~query:
        [ "client_id", [ client_id ]
        ; "redirect_uri", [ redirect_uri ]
        ; "response_type", [ "code" ]
        ; "scope", [ "https://www.googleapis.com/auth/youtube.force-ssl" ]
        ; "code_challenge", [ code_challenge ]
        ; "code_challenge_method", [ "S256" ]
        ]
      ()
  in
  let%bind () =
    Async_interactive.print_string
      [%string
        {|
Opening authentication page using $BROWSER.

If the authentication page is not automatically opened, you can also
paste the following URL into a new browser tab:

%{endpoint#Uri}
|}]
    |> Deferred.ok
  in
  let%bind () = Browse.url endpoint in
  let%bind authorization_code = authorization_code_deferred in
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
          ; "redirect_uri", [ redirect_uri ]
          ])
  in
  if response.status |> Cohttp.Code.code_of_status |> Cohttp.Code.is_success
  then (
    let%bind body = Cohttp_async.Body.to_string body |> Deferred.ok in
    let%bind json =
      Or_error.try_with (fun () -> Json.of_string body) |> Deferred.return
    in
    (* FIXME: Pass in [?file] arg. *)
    let%bind (_ : Youtube_api_oauth.Oauth.t) =
      Youtube_api_oauth.Oauth.of_json_save_to_disk json ~client_id ~client_secret
    in
    return ())
  else
    raise_s
      [%message
        "Failed to obtain access token"
          ~status:(response.status : Cohttp.Code.status_code)]
;;

module Obtain = struct
  let command =
    Command.async_or_error
      ~summary:"Generate and save valid OAuth 2.0 credentials for YouTube Data API"
      (let%map_open.Command () = return ()
       and client_id = flag "-client-id" (required string) ~doc:"STRING OAuth Client ID"
       and client_secret =
         flag "-client-secret" (required string) ~doc:"STRING OAuth Client Secret"
       in
       fun () -> obtain_access_token_and_save ~client_id ~client_secret)
  ;;
end

module Refresh = struct
  let command =
    Command.async_or_error
      ~summary:"Obtain a fresh access token from the saved refresh token"
      (let%map_open.Command () = return ()
       and force =
         flag
           "-force"
           no_arg
           ~doc:" Refresh access token even if it doesn't appear to have expired"
       in
       fun () ->
         (* FIXME: [?file] arg *)
         let%bind creds = Youtube_api_oauth.Oauth.on_disk () in
         if force || Youtube_api_oauth.Oauth.is_expired creds
         then Youtube_api_oauth.Oauth.refresh creds
         else return ())
  ;;
end

let command =
  Command.group
    ~summary:"Manage OAuth 2.0 credentials for YouTube Data API"
    [ "obtain", Obtain.command; "refresh", Refresh.command ]
;;
