open! Core
open! Async
open! Import

(* Video ID *)
type t = string

let of_string string =
  let uri = Uri.of_string string in
  let uri =
    if Option.is_some (Uri.scheme uri) then uri else Uri.of_string ("https://" ^ string)
  in
  match List.Assoc.find (Uri.query uri) "v" ~equal:String.equal with
  | Some [ video_id ] -> video_id
  | Some list -> raise_s [%message "invalid v= query parameter" (list : string list)]
  | None ->
    if [%equal: string option] (Uri.host uri) (Some "youtu.be")
    then Uri.path uri |> String.chop_prefix_exn ~prefix:"/"
    else raise_s [%message "missing v= query parameter" ~url:(Uri.to_string uri)]
;;

let video_id = Fn.id
