(** Code common to all API endpoints. *)

open! Core
open! Async
open! Import

type t

val command
  :  ?extract_exn:bool
  -> summary:string
  -> ?readme:(unit -> string)
  -> (t -> unit Or_error.t Deferred.t) Command.Param.t
  -> Command.t

val get
  :  ?body:Json.t
  -> t
  -> string
  -> params:(string, string) List.Assoc.t
  -> Json.t Or_error.t Deferred.t

val exec
  :  ?body:Json.t
  -> t
  -> string
  -> method_:Cohttp.Code.meth
  -> params:(string, string) List.Assoc.t
  -> expect_status:Cohttp.Code.status_code
  -> Json.t Or_error.t Deferred.t

val exec_expect_empty_body
  :  ?body:Json.t
  -> t
  -> string
  -> method_:Cohttp.Code.meth
  -> params:(string, string) List.Assoc.t
  -> expect_status:Cohttp.Code.status_code
  -> unit Or_error.t Deferred.t
