open! Core
open! Async
open! Import

module Credentials = struct
  type t =
    [ `Access_token of string
    | `Api_key of string
    ]

  let param =
    let open Command.Param in
    choose_one
      [ flag "access-token" (optional string) ~doc:"TOKEN YouTube API access token"
        |> map ~f:(Option.map ~f:(fun token -> `Access_token token))
      ; flag "api-key" (optional string) ~doc:"KEY YouTube API key"
        |> map ~f:(Option.map ~f:(fun key -> `Api_key key))
      ]
      ~if_nothing_chosen:`Raise
  ;;
end

type t = { credentials : Credentials.t }

let create credentials = { credentials }

let only_accept_ok code =
  match (code : Cohttp.Code.status_code) with
  | `OK -> true
  | _ -> false
;;

let call ?(accept_status = only_accept_ok) t ~method_ ~endpoint ~params =
  let uri =
    let path = "youtube/v3" ^/ endpoint in
    Uri.with_query' (Uri.make () ~scheme:"https" ~host:"www.googleapis.com" ~path) params
  in
  let headers, uri =
    match t.credentials with
    | `Access_token token ->
      Cohttp.Header.init_with "Authorization" ("Bearer " ^ token), uri
    | `Api_key key -> Cohttp.Header.init (), Uri.add_query_param' uri ("key", key)
  in
  let%bind response, body = Cohttp_async.Client.call method_ uri ~headers in
  if accept_status response.status
  then Cohttp_async.Body.to_string body |> Deferred.ok
  else (
    let%bind body = Cohttp_async.Body.to_string body in
    return
      (Or_error.error_s
         [%message
           "unacceptable status code"
             ~_:(response.status : Cohttp.Code.status_code)
             (body : string)]))
;;

let get_video_info t video_spec =
  let open Deferred.Or_error.Let_syntax in
  let video_id = Video_spec.video_id video_spec in
  let%bind json =
    call
      t
      ~method_:`GET
      ~endpoint:"videos"
      ~params:[ "id", video_id; "part", "snippet,contentDetails" ]
  in
  Deferred.return
    (Or_error.try_with (fun () ->
       let open Yojson.Basic in
       let json = from_string json in
       let video = json |> Util.member "items" |> Util.index 0 in
       let snippet = video |> Util.member "snippet" in
       let channel_id = snippet |> Util.member "channelId" |> Util.to_string in
       let channel_title = snippet |> Util.member "channelTitle" |> Util.to_string in
       let description = snippet |> Util.member "description" |> Util.to_string in
       let video_id = video_id in
       let video_title = snippet |> Util.member "title" |> Util.to_string in
       let content_details = video |> Util.member "contentDetails" in
       let duration = content_details |> Util.member "duration" |> Util.to_string in
       { Video_info.channel_id
       ; channel_title
       ; description
       ; duration
       ; video_id
       ; video_title
       }))
;;
