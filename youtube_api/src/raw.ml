open! Core
open! Async
open! Import

type t = { mutable access_token : string }

let create () =
  let%map creds = Youtube_api_oauth.Oauth.load_fresh () in
  { access_token = creds.access_token }
;;

let refresh t =
  let%map creds = Youtube_api_oauth.Oauth.load_fresh ~force_refresh:true () in
  t.access_token <- creds.access_token
;;

let command ?extract_exn ~summary ?readme param =
  Command.async_or_error
    ?extract_exn
    ~summary
    ?readme
    (let%map_open.Command () = return ()
     and () = Log.Global.set_level_via_param ()
     and main = param in
     fun () ->
       let%bind api = create () in
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
        let%bind () = refresh t in
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
  let headers, uri =
    Cohttp.Header.init_with "Authorization" ("Bearer " ^ t.access_token), uri
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
