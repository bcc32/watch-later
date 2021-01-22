open! Core
open! Async
open! Import

type t =
  { channel_id : string
  ; channel_title : string
  ; video_id : Video_id.t
  ; video_title : string
  }
[@@deriving sexp_of]

let t =
  Caqti_type.custom
    Caqti_type.(tup4 string string Video_id.t string)
    ~encode:(fun { channel_id; channel_title; video_id; video_title } ->
      Ok (channel_id, channel_title, video_id, video_title))
    ~decode:(fun (channel_id, channel_title, video_id, video_title) ->
      Ok { channel_id; channel_title; video_id; video_title })
;;
