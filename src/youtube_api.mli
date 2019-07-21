open! Core
open! Async
open! Import

module Credentials : sig
  type t =
    [ `Access_token of string
    | `Api_key of string
    ]

  val param : t Command.Param.t
end

type t

val create : Credentials.t -> t

val call
  :  ?accept_status:(Cohttp.Code.status_code -> bool)
  -> t
  -> method_:Cohttp.Code.meth
  -> endpoint:string
  -> params:(string, string) List.Assoc.t
  -> string Deferred.Or_error.t

val get_video_info : t -> Video_spec.t -> Video_info.t Deferred.Or_error.t
val get_video_json : t -> Video_spec.t -> Yojson.Basic.t Deferred.Or_error.t
