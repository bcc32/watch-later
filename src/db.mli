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
  type 'a t0 = 'a Or_error.t Deferred.t
  type 'a t1 = Sqlite3.Data.t -> 'a t0
  type 'a t2 = Sqlite3.Data.t -> 'a t1
  type 'a t3 = Sqlite3.Data.t -> 'a t2
  type 'a t4 = Sqlite3.Data.t -> 'a t3
  type 'a t5 = Sqlite3.Data.t -> 'a t4
  type arity0 = [ `Arity0 ]
  type arity1 = [ `Arity1 ]
  type arity2 = [ `Arity2 ]
  type arity3 = [ `Arity3 ]
  type arity4 = [ `Arity4 ]
  type arity5 = [ `Arity5 ]

  type ('phantom, 'f, 'a) t =
    | Arity0 : (arity0, 'a t0, 'a) t
    | Arity1 : (arity1, 'a t1, 'a) t
    | Arity2 : (arity2, 'a t2, 'a) t
    | Arity3 : (arity3, 'a t3, 'a) t
    | Arity4 : (arity4, 'a t4, 'a) t
    | Arity5 : (arity5, 'a t5, 'a) t
end

module Kind : sig
  type select = [ `Select ]
  type non_select = [ `Non_select ]

  type 'phantom t =
    | Select : select t (** Has output but makes no changes *)
    | Non_select : non_select t (** Has no output but may make changes *)
end

module Stmt : sig
  type 'desc t constraint 'desc = 'kind * 'arity

  val select
    :  ('arity, 'input_callback, unit) Arity.t
    -> ([ `Select ] * 'arity) t
    -> 'a Reader.t
    -> f:('a -> unit Deferred.t)
    -> 'input_callback

  val select_one
    :  ('arity, 'input_callback, 'a) Arity.t
    -> ([ `Select ] * 'arity) t
    -> 'a Reader.t
    -> 'input_callback

  val run
    :  ('arity, 'input_callback, int) Arity.t
    -> ([ `Non_select ] * 'arity) t
    -> 'input_callback
end

type t

val open_file : string -> t Or_error.t Deferred.t
val close : t -> unit Or_error.t Deferred.t
val with_file : string -> f:(t -> 'a Or_error.t Deferred.t) -> 'a Or_error.t Deferred.t

val prepare_exn
  :  t
  -> 'kind Kind.t
  -> ('arity, 'input_callback, 'return) Arity.t
  -> string
  -> ('kind * 'arity) Stmt.t

val define_caseless_regexp_function : t -> unit
