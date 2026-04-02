open Lwt.Syntax

type example_document = { id : int; content : string; title : string }
[@@deriving yojson]

let insert_document_example conn index_uid =
  let doc =
    {
      id = 0;
      content = "Need some content to be indexed.";
      title = "Example document";
    }
  in
  let* add_doc_task_r =
    Meilisearch_lwt.Document.add_document conn ~index_uid
      example_document_to_yojson doc
  in
  let* task_uid =
    Example_common.or_fail "add_document"
      Meilisearch_lwt.Document.error_to_string add_doc_task_r
  in
  let* task_c =
    Meilisearch_lwt.Task.wait_task conn ~max_attempts:50 ~delay:0.2 task_uid
  in
  match task_c with
  | Ok t ->
      Lwt.return
        (Printf.printf "Task: %d has completed: %s\n" task_uid
           (Meilisearch_lwt.Task.task_status_to_string t.status))
  | Error e ->
      Lwt.return
        (Printf.printf "Task: %d has failed: %s\n" task_uid
           (Meilisearch_lwt.Task.error_to_string e))

module Q = Meilisearch_lwt.Search.Query

let search_by_term conn index_uid term =
  let q =
    Q.init () |> Q.add_query term
    |> Q.add_attributes_to_retrieve [ "title"; "content" ]
  in
  let* search_results_r =
    Meilisearch_lwt.Search.search_post conn ~index_uid q
  in
  let* search_results =
    Example_common.or_fail "search_by_term"
      Meilisearch_lwt.Search.error_to_string search_results_r
  in
  Printf.printf "Search results: %s\n"
    (Yojson.Safe.pretty_to_string search_results);
  Lwt.return_unit

let add_doc_and_search conn =
  let* () = insert_document_example conn "my_first_index" in
  (* Meilisearch search is case-insensitive by default. *)
  search_by_term conn "my_first_index" "Content"

let () =
  Lwt_main.run
    (let* conn = Example_common.connect_or_fail () in
     let* () = add_doc_and_search conn in
     Lwt.return_unit)
