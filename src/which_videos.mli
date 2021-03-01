open! Core
open! Async
open! Import

type t =
  | These of Video_id.t list
  | Filter of Filter.t

val param : default:t -> t Command.Param.t
