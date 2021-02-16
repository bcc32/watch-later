open! Core
open! Async
open! Import

module Video_id_batch : sig
  type t = private Video_id.t Queue.t [@@deriving sexp_of]

  include Invariant.S with type t := t

  val max_queue_length : int
  val of_queue_exn : Video_id.t Queue.t -> t
end = struct
  type t = Video_id.t Queue.t [@@deriving sexp_of]

  let max_queue_length = 50

  let invariant t =
    Invariant.invariant [%here] t [%sexp_of: t] (fun () ->
      if Queue.length t > max_queue_length
      then
        raise_s
          [%message
            "Video ID batch too long"
              ~length:(Queue.length t : int)
              (max_queue_length : int)])
  ;;

  let of_queue_exn t =
    invariant t;
    t
  ;;
end

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

let get_video_json_batch t (video_id_batch : Video_id_batch.t) ~parts =
  let video_ids =
    (((video_id_batch :> Video_id.t Queue.t) |> Queue.to_list : Video_id.t list)
     :> string list)
    |> String.concat ~sep:","
  in
  let parts = String.concat parts ~sep:"," in
  call t ~method_:`GET ~endpoint:"videos" ~params:[ "id", video_ids; "part", parts ]
  >>| Yojson.Basic.from_string
;;

let get_video_json' t video_ids ~parts =
  video_ids
  |> Pipe.map' ~max_queue_length:Video_id_batch.max_queue_length ~f:(fun video_ids ->
    let batch = Video_id_batch.of_queue_exn video_ids in
    let%map.Deferred result = get_video_json_batch t batch ~parts in
    Queue.singleton result)
;;

let get_video_info' t video_ids =
  video_ids
  |> get_video_json' t ~parts:[ "snippet" ]
  |> Pipe.map' ~f:(fun queue ->
    Deferred.return
      (Queue.concat_map queue ~f:(fun json ->
         match json with
         | Error _ as result -> [ result ]
         | Ok json ->
           let open Yojson.Basic.Util in
           json
           |> member "items"
           |> convert_each (fun json ->
             Or_error.try_with (fun () ->
               let snippet = json |> member "snippet" in
               let channel_id =
                 snippet |> member "channelId" |> to_string
               in
               let channel_title =
                 snippet |> member "channelTitle" |> to_string
               in
               let video_id =
                 json |> member "id" |> to_string |> Video_id.of_string
               in
               let video_title = snippet |> member "title" |> to_string in
               { Video_info.channel_id
               ; channel_title
               ; video_id
               ; video_title
               })))))
;;

let get_video_info t video_id =
  get_video_info' t (Pipe.singleton video_id)
  |> Pipe.read_all
  |> Deferred.map ~f:(Fn.flip Queue.get 0)
;;

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
