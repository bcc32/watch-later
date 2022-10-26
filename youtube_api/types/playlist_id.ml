open! Core
open! Import

include
  String_id.Make
    (struct
      let module_name = "Watch_later.Playlist_id"
    end)
    ()

module Plain_or_in_url = struct
  let of_url uri =
    match List.Assoc.find (Uri.query uri) "list" ~equal:String.equal with
    | Some [ playlist_id ] -> of_string playlist_id
    | Some list -> raise_s [%message "invalid list= query parameter" (list : string list)]
    | None -> raise_s [%message "missing list= query parameter" ~url:(Uri.to_string uri)]
  ;;

  let of_string string =
    try string |> Uri.of_string |> of_url with
    | _ -> of_string string
  ;;

  let arg_type = Command.Arg_type.create of_string
end

let of_json = Of_json.string |> Of_json.map ~f:of_string
