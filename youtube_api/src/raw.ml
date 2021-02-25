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
  let rec loop tries_remaining =
    let%bind response, body =
      Monitor.try_with_or_error (fun () ->
        Cohttp_async.Client.call ?body method_ uri ~headers)
    in
    if Poly.equal `Unauthorized response.status
    then (
      let%bind () = refresh t in
      loop (tries_remaining - 1))
    else return (response, body)
  in
  loop 2
;;

let only_accept_ok : Cohttp.Code.status_code -> bool = function
  | #Cohttp.Code.success_status -> true
  | _ -> false
;;

let call ?(accept_status = only_accept_ok) ?body t ~method_ ~endpoint ~params =
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
  let%bind body = Deferred.return (Or_error.try_with (fun () -> Json.of_string body)) in
  [%log.global.debug "Received response" (response : Cohttp.Response.t) (body : Json.t)];
  if accept_status response.status
  then return body
  else
    Deferred.Or_error.error_s
      [%message
        "unacceptable status code"
          ~_:(response.status : Cohttp.Code.status_code)
          (body : Json.t)]
;;
