(** Reader monad for JSON consumers. *)

(* FIXME: Refactor this interface and expose an openable [O] module. *)

open! Core
open! Import

type 'a t

include Monad.S with type 'a t := 'a t

module Let_syntax : sig
  val return : 'a -> 'a t

  include Monad.Infix with type 'a t := 'a t

  val null : unit t
  val bool : bool t
  val string : string t
  val int : int t
  val float : float t
  val list : 'a t -> 'a list t
  val ( @. ) : string -> 'a t -> 'a t
  val ( @.? ) : string -> 'a t -> 'a option t
  val lazy_ : 'a t -> 'a Lazy.t t

  module Let_syntax : sig
    val return : 'a -> 'a t
    val bind : 'a t -> f:('a -> 'b t) -> 'b t
    val map : 'a t -> f:('a -> 'b) -> 'b t
    val both : 'a t -> 'b t -> ('a * 'b) t

    module Open_on_rhs : sig
      val return : 'a -> 'a t

      include Monad.Infix with type 'a t := 'a t

      val null : unit t
      val bool : bool t
      val string : string t
      val int : int t
      val float : float t
      val list : 'a t -> 'a list t
      val ( @. ) : string -> 'a t -> 'a t
      val ( @.? ) : string -> 'a t -> 'a option t
      val lazy_ : 'a t -> 'a Lazy.t t
    end
  end
end

(** {2 Parsing primitives} *)

val null : unit t
val bool : bool t
val string : string t
val int : int t
val float : float t
val list : 'a t -> 'a list t

(** Identity *)
val json : Json.t t

(** {2 Accessing objects} *)

(** [(name @. of_json) json] applies [of_json] to the member of JSON object [json] named
    [name]. *)
val ( @. ) : string -> 'a t -> 'a t

(** [(name @.? of_json) json] applies [of_json] to the member of JSON object [json] named
    [name].  Returns [None] if the field does not exist in the object. *)
val ( @.? ) : string -> 'a t -> 'a option t

(** [(lazy of_json) json] applies [of_json] lazily. *)
val lazy_ : 'a t -> 'a Lazy.t t

val run : Json.t -> 'a t -> 'a Or_error.t
val run_exn : Json.t -> 'a t -> 'a
