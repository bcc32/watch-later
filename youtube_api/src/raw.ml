open! Core
open! Async
open! Import

type t = { creds : Youtube_api_oauth.Oauth.t }

let create ~creds = { creds }

let command ?extract_exn ~summary ?readme param =
  Command.async_or_error
    ?extract_exn
    ~summary
    ?readme
    (let%map_open.Command () = return ()
     (* TODO: add flag for oauth credentials file *)
     and () = Log.Global.set_level_via_param ()
     and main = param in
     fun () ->
       let%bind creds = Youtube_api_oauth.Oauth.on_disk () in
       let api = create ~creds in
       main api)
;;

let http_call_internal t ?body method_ uri ~headers =
  let max_retries = 2 in
  let rec loop tries_remaining =
    let%bind response, body =
      Monitor.try_with_or_error (fun () ->
        Cohttp_async.Client.call ?body method_ uri ~headers)
    in
    if Poly.equal `Unauthorized response.status
    then (
      let tries_remaining = tries_remaining - 1 in
      if tries_remaining > 0
      then (
        [%log.global.error
          "Got HTTP 401 Unauthorized, refreshing credentials and retrying"
            (tries_remaining : int)];
        let%bind () = Youtube_api_oauth.Oauth.refresh t.creds in
        loop tries_remaining)
      else
        Deferred.Or_error.error_s
          [%message
            "Failed after retrying" (max_retries : int) (response : Cohttp.Response.t)])
    else return (response, body)
  in
  loop max_retries
;;

let status_equal : Cohttp.Code.status_code Equal.t = Poly.equal

let call ?body t endpoint ~method_ ~params ~expect_status =
  let uri =
    let path = "youtube/v3" ^/ endpoint in
    Uri.with_query' (Uri.make () ~scheme:"https" ~host:"www.googleapis.com" ~path) params
  in
  let%bind access_token = Youtube_api_oauth.Oauth.access_token t.creds in
  let headers, uri =
    Cohttp.Header.init_with "Authorization" ("Bearer " ^ access_token), uri
  in
  let body = Option.map body ~f:(fun json -> `String (Json.to_string json)) in
  [%log.global.debug
    "Making YouTube API request"
      (method_ : Cohttp.Code.meth)
      (uri : Uri_sexp.t)
      (headers : Cohttp.Header.t)
      (body : (Cohttp.Body.t option[@sexp.option]))];
  let%bind response, body = http_call_internal t ?body method_ uri ~headers in
  let%bind body = Cohttp_async.Body.to_string body |> Deferred.ok in
  [%log.global.debug "Received response" (response : Cohttp.Response.t) (body : string)];
  if status_equal response.status expect_status
  then return (response, body)
  else
    Deferred.Or_error.error_s
      [%message
        "unacceptable status code"
          ~status:(response.status : Cohttp.Code.status_code)
          ~expected:(expect_status : Cohttp.Code.status_code)
          (body : string)]
;;

let get ?body t endpoint ~params =
  let%bind _response, body =
    call ?body t endpoint ~method_:`GET ~expect_status:`OK ~params
  in
  let%bind json = Deferred.return (Or_error.try_with (fun () -> Json.of_string body)) in
  return json
;;

let exec ?body t endpoint ~method_ ~params ~expect_status =
  let%bind _response, body = call ?body t endpoint ~method_ ~expect_status ~params in
  let%bind json = Deferred.return (Or_error.try_with (fun () -> Json.of_string body)) in
  return json
;;

let exec_expect_empty_body ?body t endpoint ~method_ ~params ~expect_status =
  let%bind _response, body = call ?body t endpoint ~method_ ~expect_status ~params in
  if String.is_empty body
  then return ()
  else Deferred.Or_error.error_s [%message "Expected empty response body" (body : string)]
;;
