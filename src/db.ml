open! Core
open! Async
open! Import

module Reader = struct
  module T = struct
    type 'a t = Sqlite3.Data.t array -> Sqlite3.Data.t String.Map.t -> 'a

    let return x _ _ = x
    let map = `Custom (fun t ~f data by_headers -> f (t data by_headers))

    let apply tf tx data by_headers =
      let f = tf data by_headers in
      let x = tx data by_headers in
      f x
    ;;
  end

  module For_let_syntax = struct
    include T
    include Applicative.Make (T)
  end

  include For_let_syntax

  let by_index index data _by_headers = data.(index)
  let by_name name _data by_headers = Map.find_exn by_headers name

  module Open_on_rhs_intf = struct
    module type S = sig
      val by_index : int -> Sqlite3.Data.t t
      val by_name : string -> Sqlite3.Data.t t
    end
  end

  include Applicative.Make_let_syntax (For_let_syntax) (Open_on_rhs_intf)
      (struct
        let by_index = by_index
        let by_name = by_name
      end)

  let stmt t stmt =
    let data = Sqlite3.row_data stmt in
    let headers = Sqlite3.row_names stmt in
    let by_headers =
      Array.map2_exn data headers ~f:(fun data header -> header, data)
      |> Array.to_list
      |> String.Map.of_alist_exn
    in
    Or_error.try_with (fun () -> t data by_headers)
  ;;
end

(* TODO: More informative error messages. *)
(* TODO: Arity_n *)
(* TODO: Separate Sqlite3_with_gadts library. *)
module Arity = struct
  type t0 = unit Deferred.Or_error.t
  type t1 = Sqlite3.Data.t -> t0
  type t2 = Sqlite3.Data.t -> t1
  type t3 = Sqlite3.Data.t -> t2
  type t4 = Sqlite3.Data.t -> t3

  type 'f t =
    | Arity0 : t0 t
    | Arity1 : t1 t
    | Arity2 : t2 t
    | Arity3 : t3 t
    | Arity4 : t4 t

  let to_int (type a) : a t -> int = function
    | Arity0 -> 0
    | Arity1 -> 1
    | Arity2 -> 2
    | Arity3 -> 3
    | Arity4 -> 4
  ;;
end

module Kind = struct
  type 'kind t =
    | Select : [ `Select ] t
    | Non_select : [ `Non_select ] t
end

module Stmt = struct
  type ('kind, 'input_callback) stmt =
    | Select :
        Sqlite3.stmt * 'input_callback Arity.t
        -> ([ `Select ], 'input_callback) stmt
    | Non_select :
        Sqlite3.stmt * 'input_callback Arity.t
        -> ([ `Non_select ], 'input_callback) stmt

  type ('kind, 'input_callback) t =
    { stmt : ('kind, 'input_callback) stmt
    ; thread : In_thread.Helper_thread.t
    }

  let reset stmt =
    match Sqlite3.reset stmt with
    | OK -> Deferred.Or_error.return ()
    | rc -> Deferred.Or_error.errorf !"unexpected return code: %{Sqlite3.Rc}" rc
  ;;

  let bind stmt index data =
    match Sqlite3.bind stmt index data with
    | OK -> Deferred.Or_error.return ()
    | rc -> Deferred.Or_error.errorf !"unexpected return code: %{Sqlite3.Rc}" rc
  ;;

  let select (type i) { stmt = Select (stmt, (arity : i Arity.t)); thread } reader ~f : i
    =
    let rec loop () =
      match%bind In_thread.run ~thread (fun () -> Sqlite3.step stmt) with
      | ROW ->
        (match Reader.stmt reader stmt with
         | Error _ as err -> return err
         | Ok x ->
           let%bind () = f x in
           loop ())
      | DONE -> return (Ok ())
      | rc -> Deferred.Or_error.errorf !"unexpected return code: %{Sqlite3.Rc}" rc
    in
    let open Eager_deferred.Or_error.Let_syntax in
    match arity with
    | Arity0 ->
      let%bind () = reset stmt in
      loop ()
    | Arity1 ->
      fun a ->
        let%bind () = reset stmt in
        let%bind () = bind stmt 1 a in
        loop ()
    | Arity2 ->
      fun a b ->
        let%bind () = reset stmt in
        let%bind () = bind stmt 1 a in
        let%bind () = bind stmt 2 b in
        loop ()
    | Arity3 ->
      fun a b c ->
        let%bind () = reset stmt in
        let%bind () = bind stmt 1 a in
        let%bind () = bind stmt 2 b in
        let%bind () = bind stmt 3 c in
        loop ()
    | Arity4 ->
      fun a b c d ->
        let%bind () = reset stmt in
        let%bind () = bind stmt 1 a in
        let%bind () = bind stmt 2 b in
        let%bind () = bind stmt 3 c in
        let%bind () = bind stmt 4 d in
        loop ()
  ;;

  let run (type a) { stmt = Non_select (stmt, (arity : a Arity.t)); thread } : a =
    let run () =
      match%map In_thread.run ~thread (fun () -> Sqlite3.step stmt) with
      | DONE -> Ok ()
      | rc -> Or_error.errorf !"unexpected return code: %{Sqlite3.Rc}" rc
    in
    let open Eager_deferred.Or_error.Let_syntax in
    match arity with
    | Arity0 ->
      let%bind () = reset stmt in
      run ()
    | Arity1 ->
      fun a ->
        let%bind () = reset stmt in
        let%bind () = bind stmt 1 a in
        run ()
    | Arity2 ->
      fun a b ->
        let%bind () = reset stmt in
        let%bind () = bind stmt 1 a in
        let%bind () = bind stmt 2 b in
        run ()
    | Arity3 ->
      fun a b c ->
        let%bind () = reset stmt in
        let%bind () = bind stmt 1 a in
        let%bind () = bind stmt 2 b in
        let%bind () = bind stmt 3 c in
        run ()
    | Arity4 ->
      fun a b c d ->
        let%bind () = reset stmt in
        let%bind () = bind stmt 1 a in
        let%bind () = bind stmt 2 b in
        let%bind () = bind stmt 3 c in
        let%bind () = bind stmt 4 d in
        run ()
  ;;
end

type t =
  { db : Sqlite3.db
  ; thread : In_thread.Helper_thread.t
  ; mutable stmts : Sqlite3.stmt list
  }

let open_file file =
  let%bind thread = In_thread.Helper_thread.create () ~name:"Watch_later.Db" in
  Monitor.try_with_or_error ~name:"Watch_later.Db.open_file" (fun () ->
    let%bind db = In_thread.run ~thread (fun () -> Sqlite3.db_open file) in
    return { db; thread; stmts = [] })
;;

let close_prepared_statements t =
  Deferred.Or_error.List.iter t.stmts ~f:(fun stmt ->
    match%bind In_thread.run ~thread:t.thread (fun () -> Sqlite3.finalize stmt) with
    | OK -> Deferred.Or_error.return ()
    | rc -> Deferred.Or_error.errorf !"unexpected return code: %{Sqlite3.Rc}" rc)
;;

let close t =
  let%bind.Deferred.Or_error.Let_syntax () = close_prepared_statements t in
  if%bind In_thread.run ~thread:t.thread (fun () -> Sqlite3.db_close t.db)
  then return (Ok ())
  else Deferred.Or_error.error_string "couldn't close db handle"
;;

let with_file dbpath ~f =
  match%bind open_file dbpath with
  | Error _ as err -> return err
  | Ok t ->
    Monitor.protect
      (fun () -> f t)
      ~finally:(fun () -> Deferred.Monad_infix.(close t >>| ok_exn))
;;

let prepare_exn (type k i) t (kind : k Kind.t) (input_arity : i Arity.t) sql
  : (k, i) Stmt.t
  =
  let stmt = Sqlite3.prepare t.db sql in
  let actual_input_arity = Sqlite3.bind_parameter_count stmt in
  [%test_result: int]
    ~message:"input arity mismatch"
    actual_input_arity
    ~expect:(Arity.to_int input_arity);
  t.stmts <- stmt :: t.stmts;
  let stmt : (k, i) Stmt.stmt =
    match kind with
    | Select -> Select (stmt, input_arity)
    | Non_select -> Non_select (stmt, input_arity)
  in
  { stmt; thread = t.thread }
;;
