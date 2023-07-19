(** Extensions to [Caqti_type]. *)

open! Core
open! Async
open! Import

include module type of struct
  include Caqti_type
end

type 'a caqti_type := 'a t

val stringable : (module Stringable with type t = 'a) -> 'a t

module Record : sig
  (** Support for serializing an OCaml record in field order, in conjunction with
      [ppx_fields_conv].

      Example:

      {[
        type t =
          { foo : int
          ; bar : string
          }
        [@@deriving fields]

        let caqti_type : t Caqti_type.t =
          let open Caqti_type.Std in
          let f = Caqti_type.Record.step in
          Fields.make_creator Caqti_type.Record.init ~foo:(f int) ~bar:(f string)
          |> Caqti_type.Record.finish
        ;;
      ]} *)

  (** Difference list encoding of serialization functions for each field.

      [fields_rest] represents the fields that have not yet been folded over. *)
  type ('fields, 'fields_rest, 'record) t

  val init : ('fields, 'fields, 'record) t

  val step
    :  'f caqti_type
    -> ('record, 'f) Fieldslib.Field.t
    -> ('fields, 'f * 'fields_rest, 'record) t
    -> ('fields -> 'f) * ('fields, 'fields_rest, 'record) t

  val finish : ('fields -> 'record) * ('fields, unit, 'record) t -> 'record caqti_type
end

module Std : sig
  include module type of struct
    include Std
  end

  val video_id : Video_id.t t
  val video_info : Video_info.t t
end
