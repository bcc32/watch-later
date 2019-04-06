open! Core
open! Async
open! Import

module Reader : sig
  type 'a t

  (* TODO: Cache name->index mapping for a statement. *)
  val stmt : 'a t -> Sqlite3.stmt -> 'a
  val by_index : int -> Sqlite3.Data.t t
  val by_name : string -> Sqlite3.Data.t t

  module Open_on_rhs_intf : sig
    module type S = sig
      val by_index : int -> Sqlite3.Data.t t
      val by_name : string -> Sqlite3.Data.t t
    end
  end

  include Applicative.S with type 'a t := 'a t

  include
    Applicative.Let_syntax
    with type 'a t := 'a t
    with module Open_on_rhs_intf := Open_on_rhs_intf
end = struct
  module T = struct
    type 'a t = Sqlite3.Data.t array -> Sqlite3.Data.t String.Map.t -> 'a

    let return x _ _ = x
    let map = `Custom (fun t ~f data by_headers -> f (t data by_headers))

    let apply tf
          tx
          data
          by_headers =
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

  let by_index index
        data
        _by_headers = data.(index)

  let by_name name
        _data
        by_headers = Map.find_exn by_headers name

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
    t data by_headers
  ;;
end

(* TODO: More informative error messages. *)
(* TODO: Arity_n *)
(* TODO: Separate Sqlite3_with_gadts library. *)
module Arity = struct
  type t0 = unit
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
    | Select : [ `Select ] t (** Has output *)
    | Non_select : [ `Non_select ] t (** Has no output *)
end

module Stmt : sig
  type ('kind, 'input_callback) t

  val prepare_exn
    :  Sqlite3.db
    -> 'kind Kind.t
    -> 'input_callback Arity.t
    -> string
    -> ('kind, 'input_callback) t

  val select_exn
    :  ([ `Select ], 'input_callback) t
    -> 'a Reader.t
    -> f:('a -> unit)
    -> 'input_callback

  val run_exn : ([ `Non_select ], 'input_callback) t -> 'input_callback
end = struct
  type ('kind, 'input_callback) t =
    | Select : Sqlite3.stmt * 'input_callback Arity.t -> ([ `Select ], 'input_callback) t
    | Non_select :
        Sqlite3.stmt * 'input_callback Arity.t
        -> ([ `Non_select ], 'input_callback) t

  let prepare_exn (type k i)
        db
        (kind : k Kind.t)
        (input_arity : i Arity.t)
        sql
    : (k, i) t
    =
    let stmt = Sqlite3.prepare db sql in
    let actual_input_arity = Sqlite3.bind_parameter_count stmt in
    [%test_result: int]
      ~message:"input arity mismatch"
      actual_input_arity
      ~expect:(Arity.to_int input_arity);
    match kind with
    | Select -> Select (stmt, input_arity)
    | Non_select -> Non_select (stmt, input_arity)
  ;;

  let reset stmt =
    match Sqlite3.reset stmt with
    | OK -> ()
    | rc -> failwithf !"unexpected return code: %{Sqlite3.Rc}" rc ()
  ;;

  let bind_exn stmt index data =
    match Sqlite3.bind stmt index data with
    | OK -> ()
    | rc -> failwithf !"unexpected return code: %{Sqlite3.Rc}" rc ()
  ;;

  let select_exn (type i)
        (Select (stmt, (input_arity : i Arity.t)))
        reader
        ~f : i =
    reset stmt;
    let rec loop () =
      match Sqlite3.step stmt with
      | ROW ->
        let x = Reader.stmt reader stmt in
        f x;
        loop ()
      | DONE -> ()
      | rc -> failwithf !"unexpected return code: %{Sqlite3.Rc}" rc ()
    in
    match input_arity with
    | Arity0 -> loop ()
    | Arity1 ->
      fun a ->
        bind_exn stmt 1 a;
        loop ()
    | Arity2 ->
      fun a b ->
        bind_exn stmt 1 a;
        bind_exn stmt 2 b;
        loop ()
    | Arity3 ->
      fun a b c ->
        bind_exn stmt 1 a;
        bind_exn stmt 2 b;
        bind_exn stmt 3 c;
        loop ()
    | Arity4 ->
      fun a b c d ->
        bind_exn stmt 1 a;
        bind_exn stmt 2 b;
        bind_exn stmt 3 c;
        bind_exn stmt 4 d;
        loop ()
  ;;

  let run_exn (type a) (Non_select (stmt, (arity : a Arity.t))) : a =
    reset stmt;
    let exec () =
      match Sqlite3.step stmt with
      | DONE -> ()
      | rc -> failwithf !"unexpected return code: %{Sqlite3.Rc}" rc ()
    in
    match arity with
    | Arity0 -> exec ()
    | Arity1 ->
      fun a ->
        bind_exn stmt 1 a;
        exec ()
    | Arity2 ->
      fun a b ->
        bind_exn stmt 1 a;
        bind_exn stmt 2 b;
        exec ()
    | Arity3 ->
      fun a b c ->
        bind_exn stmt 1 a;
        bind_exn stmt 2 b;
        bind_exn stmt 3 c;
        exec ()
    | Arity4 ->
      fun a b c d ->
        bind_exn stmt 1 a;
        bind_exn stmt 2 b;
        bind_exn stmt 3 c;
        bind_exn stmt 4 d;
        exec ()
  ;;
end

type t =
  { db : Sqlite3.db
  ; setup_schema : ([ `Non_select ], Arity.t0) Stmt.t Lazy.t
  ; select_non_watched_videos : ([ `Select ], Arity.t0) Stmt.t Lazy.t
  ; select_count_total_videos : ([ `Select ], Arity.t0) Stmt.t Lazy.t
  ; select_count_watched_videos : ([ `Select ], Arity.t0) Stmt.t Lazy.t
  ; add_video_overwrite : ([ `Non_select ], Arity.t4) Stmt.t Lazy.t
  ; add_video_no_overwrite : ([ `Non_select ], Arity.t4) Stmt.t Lazy.t
  ; mark_watched : ([ `Non_select ], Arity.t1) Stmt.t Lazy.t
  ; get_random_unwatched_video : ([ `Select ], Arity.t0) Stmt.t Lazy.t
  }

let setup_schema db =
  Stmt.prepare_exn
    db
    Non_select
    Arity0
    {|
CREATE TABLE IF NOT EXISTS videos(
  video_id      TEXT PRIMARY KEY,
  video_title   TEXT,
  channel_id    TEXT,
  channel_title TEXT,
  watched       INTEGER NOT NULL DEFAULT 0
);
|}
;;

let select_non_watched_videos db =
  Stmt.prepare_exn
    db
    Select
    Arity0
    {|
SELECT channel_id, channel_title, video_id, video_title
FROM videos
WHERE NOT watched;
|}
;;

let select_count_total_videos db =
  Stmt.prepare_exn db Select Arity0 {|
SELECT COUNT(*) FROM videos;
|}
;;

let select_count_watched_videos db =
  Stmt.prepare_exn db Select Arity0 {|
SELECT COUNT(*) FROM videos
WHERE watched;
|}
;;

let add_video db ~conflict_resolution =
  let sql =
    sprintf
      {|
INSERT OR %s INTO videos
(video_id, video_title, channel_id, channel_title, watched)
VALUES (?, ?, ?, ?, 0);
|}
      conflict_resolution
  in
  Stmt.prepare_exn db Non_select Arity4 sql
;;

let add_video_overwrite db = add_video db ~conflict_resolution:"REPLACE"
let add_video_no_overwrite db = add_video db ~conflict_resolution:"IGNORE"

let mark_watched db =
  Stmt.prepare_exn
    db
    Non_select
    Arity1
    {|
UPDATE videos SET watched = 1
WHERE video_id = ?;
|}
;;

let get_random_unwatched_video db =
  Stmt.prepare_exn
    db
    Select
    Arity0
    {|
SELECT video_id, video_title, channel_id, channel_title FROM videos
WHERE NOT watched
ORDER BY RANDOM()
LIMIT 1;
|}
;;

let do_setup_schema t =
  let stmt = force t.setup_schema in
  Stmt.run_exn stmt
;;

let create ?(should_setup_schema = true) db =
  let t =
    { db
    ; setup_schema = lazy (setup_schema db)
    ; select_non_watched_videos = lazy (select_non_watched_videos db)
    ; select_count_total_videos = lazy (select_count_total_videos db)
    ; select_count_watched_videos = lazy (select_count_watched_videos db)
    ; add_video_overwrite = lazy (add_video_overwrite db)
    ; add_video_no_overwrite = lazy (add_video_no_overwrite db)
    ; mark_watched = lazy (mark_watched db)
    ; get_random_unwatched_video = lazy (get_random_unwatched_video db)
    }
  in
  if should_setup_schema then do_setup_schema t;
  t
;;

(* FIXME: This should be done asynchronously, in a thread. *)
let open_file_exn ?should_setup_schema dbpath =
  create ?should_setup_schema (Sqlite3.db_open dbpath)
;;

let rec close t =
  if Sqlite3.db_close t.db
  then return ()
  else (
    let%bind () = Clock_ns.after (Time_ns.Span.of_sec 0.05) in
    close t)
;;

let with_file_exn ?should_setup_schema dbpath ~f =
  let t = open_file_exn ?should_setup_schema dbpath in
  Monitor.protect (fun () -> f t) ~finally:(fun () -> close t)
;;

let string_exn (data : Sqlite3.Data.t) =
  match data with
  | TEXT x | BLOB x -> x
  | data -> failwithf !"expected TEXT or BLOB, got: %{Sqlite3.Data}" data ()
;;

let int64_exn (data : Sqlite3.Data.t) =
  match data with
  | INT x -> x
  | data -> failwithf !"expected INT, got: %{Sqlite3.Data}" data ()
;;

let video_info_reader =
  let open Reader.Let_syntax in
  let%map_open channel_id = by_name "channel_id" >>| string_exn
  and channel_title = by_name "channel_title" >>| string_exn
  and video_id = by_name "video_id" >>| string_exn
  and video_title = by_name "video_title" >>| string_exn in
  { Video_info.channel_id; channel_title; video_id; video_title }
;;

let iter_non_watched_videos_exn t ~f =
  let stmt = force t.select_non_watched_videos in
  Stmt.select_exn stmt video_info_reader ~f
;;

let video_stats_exn t =
  let int_reader =
    let open Reader.Let_syntax in
    Reader.by_index 0 >>| int64_exn >>| Int64.to_int_exn
  in
  let total_videos =
    let result = Set_once.create () in
    let stmt = force t.select_count_total_videos in
    Stmt.select_exn stmt int_reader ~f:(fun count ->
      Set_once.set_exn result [%here] count);
    Set_once.get_exn result [%here]
  in
  let watched_videos =
    let result = Set_once.create () in
    let stmt = force t.select_count_watched_videos in
    Stmt.select_exn stmt int_reader ~f:(fun count ->
      Set_once.set_exn result [%here] count);
    Set_once.get_exn result [%here]
  in
  { Stats.total_videos
  ; watched_videos
  ; unwatched_videos = total_videos - watched_videos
  }
;;

let add_video_exn t (video_info : Video_info.t) ~overwrite =
  (* TODO: [run_bind_by_name] *)
  let stmt =
    force (if overwrite then t.add_video_overwrite else t.add_video_no_overwrite)
  in
  Stmt.run_exn
    stmt
    (TEXT video_info.video_id)
    (TEXT video_info.video_title)
    (TEXT video_info.channel_id)
    (TEXT video_info.channel_title)
;;

let mark_watched t video_spec =
  let video_id = Video_spec.video_id video_spec in
  let stmt = force t.mark_watched in
  Stmt.run_exn stmt (TEXT video_id)
;;

let get_random_unwatched_video_exn t =
  let stmt = force t.get_random_unwatched_video in
  let result = Set_once.create () in
  Stmt.select_exn stmt video_info_reader ~f:(fun video_info ->
    Set_once.set_exn result [%here] video_info);
  match Set_once.get result with
  | None -> failwith "no unwatched videos"
  | Some video_info -> video_info
;;

(* FIXME: Remove *)
let _ = Reader.by_name, Arity.Arity2, Arity.Arity3
