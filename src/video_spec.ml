open! Core
open! Async
open! Import

type t =
  | Video_id of string
  | Video_url of Video_url.t
[@@deriving sexp_of]

let of_video_id id = Video_id id

let of_string string =
  try Video_url (string |> Video_url.of_string) with
  | _ -> Video_id string
;;
(* TODO Validate format *)

let arg_type = Command.Arg_type.create of_string

let video_id = function
  | Video_id s -> s
  | Video_url u -> Video_url.video_id u
;;
