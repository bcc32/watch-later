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
      [ flag
          "access-token"
          (optional string)
          ~doc:"TOKEN YouTube API access token (default is $YT_API_TOKEN)"
        |> map ~f:(function
          | Some token -> Some (`Access_token token)
          | None ->
            (match Sys.getenv "YT_API_TOKEN" with
             | Some token -> Some (`Access_token token)
             | None -> None))
      ; flag
          "api-key"
          (optional string)
          ~doc:"KEY YouTube API key (default is $YT_API_KEY)"
        |> map ~f:(function
          | Some key -> Some (`Api_key key)
          | None ->
            (match Sys.getenv "YT_API_KEY" with
             | Some key -> Some (`Api_key key)
             | None -> None))
      ]
      ~if_nothing_chosen:Raise
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

(* FIXME: Can raise if JSON parsing fails. *)
let get_video_json t video_spec ~parts =
  let open Deferred.Or_error.Let_syntax in
  let video_id = Video_spec.video_id video_spec in
  let parts = String.concat parts ~sep:"," in
  let%bind json =
    call t ~method_:`GET ~endpoint:"videos" ~params:[ "id", video_id; "part", parts ]
  in
  return (Yojson.Basic.from_string json)
;;

let get_video_info t video_spec =
  let open Deferred.Or_error.Let_syntax in
  let%bind json = get_video_json t video_spec ~parts:[ "snippet" ] in
  Deferred.return
    (try
       let open Yojson.Basic.Util in
       let snippet = json |> member "items" |> index 0 |> member "snippet" in
       let channel_id = snippet |> member "channelId" |> to_string in
       let channel_title = snippet |> member "channelTitle" |> to_string in
       let video_id = Video_spec.video_id video_spec in
       let video_title = snippet |> member "title" |> to_string in
       Ok { Video_info.channel_id; channel_title; video_id; video_title }
     with
     | Yojson.Basic.Util.Undefined _ ->
       Or_error.error_s [%message "Failed to get video info" (video_spec : Video_spec.t)])
;;

let get_playlist_item_ids t playlist_id =
  let open Deferred.Or_error.Let_syntax in
  let rec loop page_token rev_ids =
    let%bind json =
      call
        t
        ~method_:`GET
        ~endpoint:"playlistItems"
        ~params:
          ([ "part", "id"
           ; "playlistId", Playlist_id.to_string playlist_id
           ; "maxResults", "50"
           ]
           @
           match page_token with
           | None -> []
           | Some page_token -> [ "pageToken", page_token ])
      >>| Yojson.Basic.from_string
    in
    let%bind page_ids, next_page_token =
      try
        let open Yojson.Basic.Util in
        let page_ids =
          json
          |> member "items"
          |> convert_each (fun item -> item |> member "id" |> to_string)
        in
        let next_page_token = json |> member "nextPageToken" |> to_string_option in
        return (page_ids, next_page_token)
      with
      | e ->
        Deferred.Or_error.error_s
          [%message
            "Failed to read playlist item IDs"
              (playlist_id : Playlist_id.t)
              (e : exn)
              ~json:(Yojson.Basic.to_string json : string)]
    in
    let rev_ids = List.rev_append page_ids rev_ids in
    match next_page_token with
    | None -> return (List.rev rev_ids)
    | Some page_token -> loop (Some page_token) rev_ids
  in
  loop None []
;;

(* FIXME: Polymorphic comparison *)
let delete_playlist_item t playlist_item_id =
  call
    t
    ~method_:`DELETE
    ~endpoint:"playlistItems"
    ~accept_status:(Poly.( = ) `No_content)
    ~params:[ "id", playlist_item_id ]
  |> Deferred.Or_error.ignore_m
;;

let clear_playlist t playlist_id =
  let open Deferred.Or_error.Let_syntax in
  let%bind playlist_item_ids = get_playlist_item_ids t playlist_id in
  Deferred.Or_error.List.iter playlist_item_ids ~f:(delete_playlist_item t)
;;
