open! Core
open! Async
open! Import
include Caqti_type

let stringable (type a) (module M : Stringable with type t = a) : a t =
  let open M in
  custom
    string
    ~encode:(fun t -> Ok (to_string t))
    ~decode:(fun s ->
      Or_error.try_with (fun () -> of_string s) |> Result.map_error ~f:Error.to_string_hum)
;;

let video_id = stringable (module Video_id)

module Record = struct
  type 'a caqti_type = 'a t

  type ('fields, 'fields_rest, 'a) t =
    { unwrap : 'fields -> 'fields_rest
    ; encode : ('a -> 'fields_rest) -> 'a -> 'fields
    ; caqti_type : 'fields_rest caqti_type -> 'fields caqti_type
    }

  let finish
        (type a fields)
        ( (decode : fields -> a)
        , ({ unwrap = _; encode; caqti_type } : (fields, unit, a) t) )
    : a caqti_type
    =
    let encode = encode (Fn.const ()) in
    let caqti_type = caqti_type unit in
    custom caqti_type ~encode:(fun x -> Ok (encode x)) ~decode:(fun x -> Ok (decode x))
  ;;

  let init (type fields) : (fields, fields, _) t =
    { unwrap = Fn.id; encode = Fn.id; caqti_type = Fn.id }
  ;;

  let step
        (type fields fields_rest a this_field)
        (type_ : this_field caqti_type)
        (field : (a, this_field) Fieldslib.Field.t)
        ({ unwrap; encode; caqti_type } : (fields, this_field * fields_rest, a) t)
    : (fields -> this_field) * (fields, fields_rest, a) t
    =
    let encode encode_rest =
      encode (fun record -> Fieldslib.Field.get field record, encode_rest record)
    in
    let caqti_type rest = caqti_type (t2 type_ rest) in
    fst << unwrap, { unwrap = snd << unwrap; encode; caqti_type }
  ;;
end

let time_ns =
  custom
    string
    ~encode:(Time_ns.to_string_iso8601_basic ~zone:Time_ns_unix.Zone.utc >> Result.return)
    ~decode:(fun s ->
      try Ok (Time_ns.of_string_with_utc_offset s) with
      | _ -> Error (sprintf "Could not parse timestamp %S" s))
;;

let span_ns =
  custom
    int
    ~encode:(Time_ns.Span.to_int_sec >> Result.return)
    ~decode:(Time_ns.Span.of_int_sec >> Result.return)
;;

let video_info =
  Video_info.Fields.make_creator
    Record.init
    ~channel_id:(Record.step string)
    ~channel_title:(Record.step string)
    ~video_id:(Record.step video_id)
    ~video_title:(Record.step string)
    ~published_at:(Record.step (option time_ns))
    ~duration:(Record.step (option span_ns))
  |> Record.finish
;;

module Std = struct
  include Std

  let span_ns = span_ns
  let time_ns = time_ns
  let video_id = video_id
  let video_info = video_info
end
