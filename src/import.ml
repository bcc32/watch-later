open! Core
open! Async

let max_concurrent_jobs =
  match Linux_ext.cores with
  | Ok f -> f ()
  | Error _ -> 4
;;

let download_throttle = Throttle.create ~continue_on_error:true ~max_concurrent_jobs

include Int.Replace_polymorphic_compare
