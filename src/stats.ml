open! Core
open! Async
open! Import

type t =
  { total_videos : int
  ; watched_videos : int
  ; unwatched_videos : int
  }
[@@deriving sexp_of]
