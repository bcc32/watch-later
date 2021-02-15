open! Core
open! Async
open! Import
open Deferred.Or_error.Let_syntax

let log =
  Log.create
    ~level:`Info
    ~output:[ Log.Output.stderr ~format:`Sexp_hum () ]
    ~on_error:`Raise
    ()
;;

type t =
  { access_token : string
  ; log : Log.t
  }

let create () =
  let%map creds = Oauth.load_fresh () in
  { access_token = creds.access_token; log }
;;

let command ?extract_exn ~summary ?readme param =
  Command.async_or_error
    ?extract_exn
    ~summary
    ?readme
    (let%map_open.Command () = return ()
     and () = Log.set_level_via_param log
     and main = param in
     fun () ->
       let%bind api = create () in
       main api)
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
  let body = Option.map body ~f:(fun json -> `String (Yojson.Basic.to_string json)) in
  [%log.debug
    t.log
      "Making YouTube API request"
      (method_ : Cohttp.Code.meth)
      (uri : Uri_sexp.t)
      (headers : Cohttp.Header.t)
      (body : (Cohttp.Body.t option[@sexp.option]))];
  let%bind response, body =
    Cohttp_async.Client.call ?body method_ uri ~headers |> Deferred.ok
  in
  let%bind body = Cohttp_async.Body.to_string body |> Deferred.ok in
  [%log.debug t.log "Received response" (response : Cohttp.Response.t) (body : string)];
  if accept_status response.status
  then return body
  else
    Deferred.Or_error.error_s
      [%message
        "unacceptable status code"
          ~_:(response.status : Cohttp.Code.status_code)
          (body : string)]
;;

(* FIXME: Can raise if JSON parsing fails. *)
let get_video_json t video_id ~parts =
  let open Deferred.Or_error.Let_syntax in
  let parts = String.concat parts ~sep:"," in
  let%bind json =
    call
      t
      ~method_:`GET
      ~endpoint:"videos"
      ~params:[ "id", Video_id.to_string video_id; "part", parts ]
  in
  return (Yojson.Basic.from_string json)
;;

let get_video_info t video_id =
  let open Deferred.Or_error.Let_syntax in
  let%bind json = get_video_json t video_id ~parts:[ "snippet" ] in
  Deferred.return
    (try
       let open Yojson.Basic.Util in
       let snippet = json |> member "items" |> index 0 |> member "snippet" in
       let channel_id = snippet |> member "channelId" |> to_string in
       let channel_title = snippet |> member "channelTitle" |> to_string in
       let video_title = snippet |> member "title" |> to_string in
       Ok { Video_info.channel_id; channel_title; video_id; video_title }
     with
     | Yojson.Basic.Util.Undefined _ ->
       Or_error.error_s [%message "Failed to get video info" (video_id : Video_id.t)])
;;

let get_playlist_items ?video_id t playlist_id =
  let open Deferred.Or_error.Let_syntax in
  let rec loop page_token rev_items =
    let%bind json =
      call
        t
        ~method_:`GET
        ~endpoint:"playlistItems"
        ~params:
          ([ "part", "id,contentDetails"
           ; "playlistId", Playlist_id.to_string playlist_id
           ; "maxResults", "50"
           ]
           @ (match page_token with
             | None -> []
             | Some page_token -> [ "pageToken", page_token ])
           @
           match video_id with
           | None -> []
           | Some video_id -> [ "videoId", Video_id.to_string video_id ])
      >>| Yojson.Basic.from_string
    in
    let%bind page_items, next_page_token =
      try
        let open Yojson.Basic.Util in
        let page_items =
          json
          |> member "items"
          |> convert_each (fun item ->
            let id = item |> member "id" |> to_string in
            let video_id =
              item
              |> member "contentDetails"
              |> member "videoId"
              |> to_string
              |> Video_id.of_string
            in
            ({ id; video_id } : Playlist_item.t))
        in
        let next_page_token = json |> member "nextPageToken" |> to_string_option in
        return (page_items, next_page_token)
      with
      | e ->
        Deferred.Or_error.error_s
          [%message
            "Failed to read playlist item IDs"
              (playlist_id : Playlist_id.t)
              (e : exn)
              ~json:(Yojson.Basic.to_string json : string)]
    in
    let rev_items = List.rev_append page_items rev_items in
    match next_page_token with
    | None -> return (List.rev rev_items)
    | Some page_token -> loop (Some page_token) rev_items
  in
  loop None []
;;

let delete_playlist_item t playlist_item_id =
  call t ~method_:`DELETE ~endpoint:"playlistItems" ~params:[ "id", playlist_item_id ]
  |> Deferred.Or_error.ignore_m
;;

let append_video_to_playlist t playlist_id video_id =
  call
    t
    ~method_:`POST
    ~endpoint:"playlistItems"
    ~params:[ "part", "snippet" ]
    ~body:
      (`Assoc
         [ "kind", `String "youtube#playlistItem"
         ; ( "snippet"
           , `Assoc
               [ "playlistId", `String (Playlist_id.to_string playlist_id)
               ; ( "resourceId"
                 , `Assoc
                     [ "kind", `String "youtube#video"
                     ; "videoId", `String (Video_id.to_string video_id)
                     ] )
               ] )
         ])
  |> Deferred.Or_error.ignore_m
;;
