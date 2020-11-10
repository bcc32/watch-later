open! Core
open! Async
open! Import

let url url =
  let browser =
    match Bos.OS.Env.(parse "BROWSER" (some cmd)) ~absent:None with
    | Ok cmd -> cmd
    | Error (`Msg s) ->
      raise_s [%message "Error parsing BROWSER environment variable" ~_:(s : string)]
  in
  Webbrowser.reload ?browser (Uri.to_string url)
  |> Result.map_error ~f:(fun (`Msg s) -> Error.of_string s)
;;
