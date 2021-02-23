open! Core
open! Async
open! Import
module Video_info = Video_info

let max_batch_size = 50

module Video_id_batch : sig
  type t = private Video_id.t Queue.t [@@deriving sexp_of]

  include Invariant.S with type t := t

  val of_queue_exn : Video_id.t Queue.t -> t
end = struct
  type t = Video_id.t Queue.t [@@deriving sexp_of]

  let invariant t =
    Invariant.invariant [%here] t [%sexp_of: t] (fun () ->
      if Queue.length t > max_batch_size
      then
        raise_s
          [%message
            "Video ID batch too long"
              ~length:(Queue.length t : int)
              (max_batch_size : int)])
  ;;

  let of_queue_exn t =
    invariant t;
    t
  ;;
end

type t = { access_token : string }

let create () =
  let%map creds = Youtube_api_oauth.Oauth.load_fresh () in
  { access_token = creds.access_token }
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
  [%log.global.debug
    "Making YouTube API request"
      (method_ : Cohttp.Code.meth)
      (uri : Uri_sexp.t)
      (headers : Cohttp.Header.t)
      (body : (Cohttp.Body.t option[@sexp.option]))];
  let%bind response, body =
    Cohttp_async.Client.call ?body method_ uri ~headers |> Deferred.ok
  in
  let%bind body = Cohttp_async.Body.to_string body |> Deferred.ok in
  [%log.global.debug "Received response" (response : Cohttp.Response.t) (body : string)];
  if accept_status response.status
  then return body
  else
    Deferred.Or_error.error_s
      [%message
        "unacceptable status code"
          ~_:(response.status : Cohttp.Code.status_code)
          (body : string)]
;;

let get_video_json_batch t (video_id_batch : Video_id_batch.t) ~parts =
  let video_ids =
    ((video_id_batch :> Video_id.t Queue.t)
     |> Queue.to_list
     |> Set.stable_dedup_list (module Video_id)
     :> string list)
  in
  let%bind json =
    call
      t
      ~method_:`GET
      ~endpoint:"videos"
      ~params:
        [ "id", String.concat ~sep:"," video_ids; "part", String.concat ~sep:"," parts ]
  in
  let%bind json =
    Deferred.return (Or_error.try_with (fun () -> Yojson.Basic.from_string json))
  in
  let%bind items_by_id =
    Deferred.return
      (Or_error.try_with (fun () ->
         let open Yojson.Basic.Util in
         json
         |> member "items"
         |> convert_each (fun json ->
           json |> member "id" |> to_string |> Video_id.of_string, json)
         |> Map.of_alist_exn (module Video_id)))
  in
  return
    (Queue.map
       (video_id_batch :> Video_id.t Queue.t)
       ~f:(fun video_id ->
         match Map.find items_by_id video_id with
         | Some json -> Ok json
         | None -> Or_error.error_s [%message "No such video" (video_id : Video_id.t)]))
;;

let get_video_json' t video_ids ~parts =
  video_ids
  |> Pipe.map' ~max_queue_length:max_batch_size ~f:(fun video_ids ->
    let batch = Video_id_batch.of_queue_exn video_ids in
    match%map.Deferred get_video_json_batch t batch ~parts with
    | Error _ as result -> Queue.singleton result
    | Ok results -> results)
;;

let get_video_info' t video_ids =
  video_ids
  |> get_video_json' t ~parts:[ "snippet" ]
  |> Pipe.map
       ~f:
         (Or_error.bind ~f:(fun json ->
            let open Yojson.Basic.Util in
            Or_error.try_with (fun () ->
              let snippet = json |> member "snippet" in
              let channel_id = snippet |> member "channelId" |> to_string in
              let channel_title = snippet |> member "channelTitle" |> to_string in
              let video_id = json |> member "id" |> to_string |> Video_id.of_string in
              let video_title = snippet |> member "title" |> to_string in
              { Video_info.channel_id; channel_title; video_id; video_title })))
;;

let get_video_info t video_id =
  get_video_info' t (Pipe.singleton video_id)
  |> Pipe.read_all
  |> Deferred.map ~f:(Fn.flip Queue.get 0)
;;

(* TODO: Generalize pagination logic *)
let get_playlist_items ?video_id t playlist_id =
  let rec loop page_token rev_items =
    let%bind json =
      call
        t
        ~method_:`GET
        ~endpoint:"playlistItems"
        ~params:
          ([ "part", "id,contentDetails"
           ; "playlistId", Playlist_id.to_string playlist_id
           ; "maxResults", Int.to_string max_batch_size
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
        (* TODO: [Playlist_item.of_json], etc. *)
        let page_items =
          json
          |> member "items"
          |> convert_each (fun item ->
            let id =
              item |> member "id" |> to_string |> Playlist_item.Id.of_string
            in
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
  call
    t
    ~method_:`DELETE
    ~endpoint:"playlistItems"
    ~params:[ "id", Playlist_item.Id.to_string playlist_item_id ]
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
