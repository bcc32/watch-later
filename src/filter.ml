open! Core
open! Async
open! Import
module Caqti_type = Db_type
open Caqti_type.Std

type t =
  { channel_id : string option
  ; channel_title : string option
  ; video_id : Video_id.t option
  ; video_title : string option
  ; watched : bool option
  }
[@@deriving fields]

let is_empty =
  let is_none _ _ = Option.is_none in
  Fields.Direct.for_all
    ~channel_id:is_none
    ~channel_title:is_none
    ~video_id:is_none
    ~video_title:is_none
    ~watched:is_none
;;

let empty =
  { channel_id = None
  ; channel_title = None
  ; video_id = None
  ; video_title = None
  ; watched = None
  }
;;

let unwatched =
  { channel_id = None
  ; channel_title = None
  ; video_id = None
  ; video_title = None
  ; watched = Some false
  }
;;

let param =
  let%map_open.Command () = return ()
  and channel_id = flag "-channel-id" (optional string) ~doc:"ID channel ID"
  and channel_title = flag "-channel-title" (optional string) ~doc:"TITLE channel TITLE"
  and video_id =
    flag "-video-id" (optional Video_id.Plain_or_in_url.arg_type) ~doc:"ID video ID"
  and video_title = flag "-video-title" (optional string) ~doc:"TITLE video TITLE"
  and watched =
    flag
      "-watched"
      (optional bool)
      ~doc:"BOOL Restrict to videos with watched status BOOL"
  in
  { channel_id; channel_title; video_id; video_title; watched }
;;

let t : t Caqti_type.t =
  let f = Caqti_type.Record.step in
  Fields.make_creator
    Caqti_type.Record.init
    ~channel_id:(f (option string))
    ~channel_title:(f (option string))
    ~video_id:(f (option Caqti_type.Std.video_id))
    ~video_title:(f (option string))
    ~watched:(f (option bool))
  |> Caqti_type.Record.finish
;;
