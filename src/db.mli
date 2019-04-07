open! Core
open! Async
open! Import

module Reader : sig
  type 'a t

  (* TODO: Cache name->index mapping for a statement. *)
  val stmt : 'a t -> Sqlite3.stmt -> 'a
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
  type t0 = unit Deferred.t
  type t1 = Sqlite3.Data.t -> t0
  type t2 = Sqlite3.Data.t -> t1
  type t3 = Sqlite3.Data.t -> t2
  type t4 = Sqlite3.Data.t -> t3

  type 'f t =
    | Arity0 : t0 t
    | Arity1 : t1 t
    | Arity2 : t2 t
    | Arity3 : t3 t
    | Arity4 : t4 t
end

module Kind : sig
  type 'kind t =
    | Select : [ `Select ] t (** Has output *)
    | Non_select : [ `Non_select ] t (** Has no output *)
end

module Stmt : sig
  type ('kind, 'input_callback) t

  val select_exn
    :  ([ `Select ], 'input_callback) t
    -> 'a Reader.t
    -> f:('a -> unit)
    -> 'input_callback

  val select_exn'
    :  ([ `Select ], 'input_callback) t
    -> 'a Reader.t
    -> f:('a -> unit Deferred.t)
    -> 'input_callback

  val run_exn : ([ `Non_select ], 'input_callback) t -> 'input_callback
end

type t

val open_file : string -> t Deferred.t
val close : t -> unit Deferred.t
val with_file : string -> f:(t -> unit Deferred.t) -> unit Deferred.t

val prepare_exn
  :  t
  -> 'kind Kind.t
  -> 'input_callback Arity.t
  -> string
  -> ('kind, 'input_callback) Stmt.t
