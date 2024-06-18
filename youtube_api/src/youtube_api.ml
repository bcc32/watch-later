open! Core
open! Async
open! Import

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

include Raw

let get_video_json_batch t (video_id_batch : Video_id_batch.t) ~parts =
  let video_ids =
    ((video_id_batch :> Video_id.t Queue.t)
     |> Queue.to_list
     |> Set.stable_dedup_list (module Video_id)
      :> string list)
  in
  let%bind json =
    get
      t
      "videos"
      ~params:
        [ "id", String.concat ~sep:"," video_ids; "part", String.concat ~sep:"," parts ]
  in
  let%bind items_by_id =
    Deferred.return
      (Of_json.run
         json
         Of_json.(
           "items"
           @. list
                (let%map_open.Of_json id = "id" @. Video_id.of_json
                 and json = json in
                 id, json)
           >>| Map.of_alist_exn (module Video_id)))
  in
  return
    (Queue.map
       (video_id_batch :> Video_id.t Queue.t)
       ~f:(fun video_id ->
         match Map.find items_by_id video_id with
         | Some json -> Ok json
         | None -> Or_error.error_s [%message "No such video" (video_id : Video_id.t)]))
;;

let get_video_json t video_ids ~parts =
  video_ids
  |> Pipe.map' ~max_queue_length:max_batch_size ~f:(fun video_ids ->
    let batch = Video_id_batch.of_queue_exn video_ids in
    match%map.Deferred get_video_json_batch t batch ~parts with
    | Error _ as result -> Queue.singleton result
    | Ok results -> results)
;;

let get_video_info t video_ids =
  video_ids
  |> get_video_json t ~parts:[ "snippet" ]
  |> Pipe.map
       ~f:
         (Or_error.bind ~f:(fun json ->
            Of_json.run
              json
              (let%map_open.Of_json channel_id, channel_title, video_title =
                 "snippet"
                 @.
                 let%map_open.Of_json channel_id = "channelId" @. string
                 and channel_title = "channelTitle" @. string
                 and video_title = "title" @. string in
                 channel_id, channel_title, video_title
               and video_id = "id" @. Video_id.of_json in
               { Video_info.channel_id; channel_title; video_id; video_title })))
;;

(* TODO: Generalize pagination logic *)
let get_playlist_items t playlist_id =
  let get_playlist_page page_token =
    let%bind json =
      get
        t
        "playlistItems"
        ~params:
          ([ "part", "id,snippet"
           ; "playlistId", Playlist_id.to_string playlist_id
           ; "maxResults", Int.to_string max_batch_size
           ]
           @
           match page_token with
           | None -> []
           | Some page_token -> [ "pageToken", page_token ])
        ~should_retry:(fun response ~body:json ->
          Poly.equal `Bad_request response.status
          &&
          match
            Of_json.run
              (Option.value_exn json)
              (let%map_open.Of_json () = return ()
               and reasons = "error" @. "errors" @. list ("reason" @. string) in
               reasons)
          with
          | Ok [ "invalidPageToken" ] -> true
          | Ok reasons ->
            Debug.eprint_s [%message (reasons : string list)];
            false
          | _ | (exception _) -> false)
    in
    let%bind page_items, next_page_token =
      Of_json.run
        json
        (let%map_open.Of_json () = return ()
         and page_items = "items" @. list Playlist_item.of_json
         and next_page_token = "nextPageToken" @.? string in
         page_items, next_page_token)
      |> Deferred.return
    in
    return (page_items, next_page_token)
  in
  Pipe.create_reader ~close_on_exception:false (fun writer ->
    let rec loop page_token =
      match%bind.Deferred get_playlist_page page_token with
      | Ok (page_items, next_page_token) ->
        let%bind.Deferred () =
          Pipe.transfer_in
            writer
            ~from:(page_items |> List.map ~f:Or_error.return |> Queue.of_list)
        in
        (match next_page_token with
         | None -> Deferred.return ()
         | Some page_token -> loop (Some page_token))
      | Error _ as result -> Pipe.write writer result
    in
    loop None)
;;

let delete_playlist_item t playlist_item_id =
  exec_expect_empty_body
    t
    "playlistItems"
    ~method_:`DELETE
    ~params:[ "id", Playlist_item.Id.to_string playlist_item_id ]
    ~expect_status:`No_content
;;

let append_video_to_playlist t playlist_id video_id =
  exec
    t
    "playlistItems"
    ~method_:`POST
    ~params:[ "part", "snippet" ]
    ~body:
      (`Object
          [ "kind", `String "youtube#playlistItem"
          ; ( "snippet"
            , `Object
                [ "playlistId", `String (Playlist_id.to_string playlist_id)
                ; ( "resourceId"
                  , `Object
                      [ "kind", `String "youtube#video"
                      ; "videoId", `String (Video_id.to_string video_id)
                      ] )
                ] )
          ])
    ~expect_status:`OK
  |> Deferred.Or_error.ignore_m
;;
