open! Core
open! Async
open! Import

let validate id =
  if String.length id <> 11
  then
    error_s
      [%message
        "Video ID had unexpected length" ~expected:11 ~actual:(String.length id : int)]
  else (
    match
      String.find id ~f:(function
        | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '-' | '_' -> false
        | _ -> true)
    with
    | None -> Ok ()
    | Some char -> error_s [%message "Invalid character in video ID" (char : char)])
;;

include String_id.Make_with_validate
    (struct
      let module_name = "Watch_later.Video_id"
      let validate = validate
    end)
    ()

module Plain_or_in_url = struct
  let of_url uri =
    match List.Assoc.find (Uri.query uri) "v" ~equal:String.equal with
    | Some [ video_id ] -> of_string video_id
    | Some list -> raise_s [%message "invalid v= query parameter" (list : string list)]
    | None ->
      if [%equal: string option] (Uri.host uri) (Some "youtu.be")
      then of_string (Uri.path uri |> String.chop_prefix_exn ~prefix:"/")
      else raise_s [%message "missing v= query parameter" ~url:(Uri.to_string uri)]
  ;;

  let of_string string =
    try string |> Uri.of_string |> of_url with
    | _ -> of_string string
  ;;

  let arg_type = Command.Arg_type.create of_string
end

let t =
  Caqti_type.custom
    Caqti_type.string
    ~encode:(fun t -> Ok (to_string t))
    ~decode:(fun s ->
      Or_error.try_with (fun () -> of_string s) |> Result.map_error ~f:Error.to_string_hum)
;;
