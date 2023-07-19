open! Core
open! Import

type 'a t = Json.t -> 'a

let return x = Fn.const x
let bind parse ~f json = f (parse json) json
let map parse ~f json = f (parse json)

include Monad.Make (struct
    type nonrec 'a t = 'a t

    let return = return
    let bind = bind
    let map = `Custom map
  end)

exception
  Of_json of
    { context : string list
    ; json : Json.t
    ; exn : exn
    }
[@@deriving sexp_of]

exception
  Type_error of
    { expected : string
    ; got : string
    }
[@@deriving sexp_of]

let with_empty_context parse json =
  try parse json with
  | Of_json _ as exn -> raise exn
  | exn -> raise (Of_json { context = []; json; exn })
;;

let with_context ctx parse json =
  try parse json with
  | Of_json { context; json; exn } ->
    raise (Of_json { context = ctx :: context; json; exn })
  | exn -> raise (Of_json { context = [ ctx ]; json; exn })
;;

let assoc_exn pairs key ~if_none ~if_one =
  match
    List.filter_map pairs ~f:(fun (key', v) ->
      if String.equal key key' then Some v else None)
  with
  | [] -> if_none key
  | [ json ] -> if_one json
  | _ :: _ :: _ as values ->
    raise_s [%message "Duplicate key in object" (key : string) (values : Json.t list)]
;;

let raise_type_error ~expected ~got = raise (Type_error { expected; got })

let ( @. ) field parse json =
  let assoc = Jsonaf.assoc_list_exn json in
  assoc_exn
    assoc
    field
    ~if_none:(fun key -> raise_s [%message "Missing key in object" (key : string)])
    ~if_one:(fun member -> with_context field parse member)
;;

let ( @.? ) field parse json =
  let assoc = Jsonaf.assoc_list_exn json in
  assoc_exn
    assoc
    field
    ~if_none:(fun _ -> None)
    ~if_one:(fun member -> with_context field parse member |> Some)
;;

let null json =
  let raise_type_error got = raise_type_error ~expected:"null" ~got in
  match json with
  | `False | `True -> raise_type_error "bool"
  | `Null -> ()
  | `Object _ -> raise_type_error "object"
  | `Array _ -> raise_type_error "array"
  | `Number _ -> raise_type_error "float"
  | `String _ -> raise_type_error "string"
;;

let null = with_empty_context null
let bool = with_empty_context Jsonaf.bool_exn
let string = with_empty_context Jsonaf.string_exn
let number = with_empty_context Jsonaf.float_exn
let list parse = with_empty_context (Jsonaf.Export.list_of_jsonaf parse)
let json = Fn.id
let lazy_ parse json = lazy (parse json)

module Let_syntax = struct
  include Let_syntax

  let null = null
  let bool = bool
  let string = string
  let number = number
  let list = list
  let ( @. ) = ( @. )
  let ( @.? ) = ( @.? )
  let lazy_ = lazy_

  module Let_syntax = struct
    include Let_syntax

    module Open_on_rhs = struct
      include Monad_infix

      let return = return
      let null = null
      let bool = bool
      let string = string
      let number = number
      let list = list
      let ( @. ) = ( @. )
      let ( @.? ) = ( @.? )
      let lazy_ = lazy_
    end
  end
end

let run json parse =
  try Ok (with_empty_context parse json) with
  | Of_json { context; json; exn } ->
    Or_error.error_s
      [%message
        "Failed to parse JSON" (context : string list) (json : Json.t) (exn : exn)]
;;

let run_exn json parse = run json parse |> Or_error.ok_exn
