open! Core
open! Async
open! Import

let url url =
  let%bind browser =
    match Bos.OS.Env.(parse "BROWSER" (some cmd)) ~absent:None with
    | Ok cmd -> return cmd
    | Error (`Msg s) ->
      Deferred.Or_error.error_s
        [%message "Error parsing BROWSER environment variable" ~_:(s : string)]
  in
  Monitor.try_with_join_or_error
    ~name:"browse"
    ~info:
      (Info.of_lazy_t (lazy (Info.create_s [%message "Browse.url" (url : Uri_sexp.t)])))
    (fun () ->
      In_thread.run (fun () -> Webbrowser.reload ?browser (Uri.to_string url))
      |> Deferred.Result.map_error ~f:(fun (`Msg s) -> Error.of_string s))
;;
