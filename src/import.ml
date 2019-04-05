open! Core
open! Async

let max_concurrent_jobs =
  match Linux_ext.cores with
  | Ok f -> f ()
  | Error _ -> 4
;;

include Expect_test_helpers
include Int.Replace_polymorphic_compare
