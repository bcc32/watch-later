open! Core
open! Async
open! Import

module Reader : sig
  type 'a t

  (* TODO: Cache name->index mapping for a statement. *)
  val stmt : 'a t -> Sqlite3.stmt -> 'a Or_error.t
  val by_index : int -> Sqlite3.Data.t t
  val by_name : string -> Sqlite3.Data.t t

  module Open_on_rhs_intf : sig
    module type S = sig
      val by_index : int -> Sqlite3.Data.t t
      val by_name : string -> Sqlite3.Data.t t
    end
  end

  include Applicative.S with type 'a t := 'a t

  include
    Applicative.Let_syntax
    with type 'a t := 'a t
    with module Open_on_rhs_intf := Open_on_rhs_intf
end

module Arity : sig
  type 'a t0 = 'a Deferred.Or_error.t
  type 'a t1 = Sqlite3.Data.t -> 'a t0
  type 'a t2 = Sqlite3.Data.t -> 'a t1
  type 'a t3 = Sqlite3.Data.t -> 'a t2
  type 'a t4 = Sqlite3.Data.t -> 'a t3
  type 'a t5 = Sqlite3.Data.t -> 'a t4

  type ('f, 'a) t =
    | Arity0 : ('a t0, 'a) t
    | Arity1 : ('a t1, 'a) t
    | Arity2 : ('a t2, 'a) t
    | Arity3 : ('a t3, 'a) t
    | Arity4 : ('a t4, 'a) t
    | Arity5 : ('a t5, 'a) t
end

module Kind : sig
  type ('kind, 'return) t =
    | Select : ([ `Select ], unit) t (** Has output but makes no changes *)
    | Non_select : ([ `Non_select ], int) t (** Has no output but may make changes *)
end

module Stmt : sig
  type ('kind, 'input_callback) t

  val select
    :  ([ `Select ], 'input_callback) t
    -> 'a Reader.t
    -> f:('a -> unit Deferred.t)
    -> 'input_callback

  val run : ([ `Non_select ], 'input_callback) t -> 'input_callback
end

type t

val open_file : string -> t Deferred.Or_error.t
val close : t -> unit Deferred.Or_error.t
val with_file : string -> f:(t -> 'a Deferred.Or_error.t) -> 'a Deferred.Or_error.t

val prepare_exn
  :  t
  -> ('kind, 'return) Kind.t
  -> ('input_callback, 'return) Arity.t
  -> string
  -> ('kind, 'input_callback) Stmt.t
