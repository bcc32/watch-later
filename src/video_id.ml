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
