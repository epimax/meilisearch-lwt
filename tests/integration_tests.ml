module Common = struct
  let url_env = "MEILISEARCH_URL"
  let api_key_env = "MEILISEARCH_API_KEY"

  let missing_env_message var =
    Printf.sprintf
      "Missing required environment variable %s. Example: \
       %s=http://localhost:7700 %s=<api-key> dune exec \
       tests/integration_tests.exe"
      var url_env api_key_env

  let getenv_required var =
    match Sys.getenv_opt var with
    | Some value when String.trim value <> "" -> value
    | _ -> Alcotest.fail (missing_env_message var)

  let url () = getenv_required url_env
  let api_key () = getenv_required api_key_env
  let invalid_api_key () = api_key () ^ "_invalid"
  let connect url key = Meilisearch_lwt.connect ~url ~key
  let connect_configured () = connect (url ()) (api_key ())

  let get_configured_connection () =
    let open Lwt.Syntax in
    let* conn_r = connect_configured () in
    match conn_r with
    | Ok conn -> Lwt.return conn
    | Error e ->
        Alcotest.fail
          ("Should have connected to configured Meilisearch instance: "
          ^ Meilisearch_lwt.error_to_string e)

  let get_task conn task_uid = Meilisearch_lwt.Task.get_task conn ~task_uid
  let get_index conn index_uid = Meilisearch_lwt.Index.get_index conn ~index_uid

  let create_index conn index_uid pk =
    Meilisearch_lwt.Index.create_index conn ~index_uid ~pk

  let delete_index conn index_uid =
    Meilisearch_lwt.Index.delete_index conn ~index_uid

  let wait_task conn task_uid =
    Meilisearch_lwt.Task.wait_task conn ~max_attempts:50 ~delay:0.2 task_uid

  let add_document conn index_uid to_yojson doc =
    Meilisearch_lwt.Document.add_document conn ~index_uid to_yojson doc

  let add_documents conn index_uid to_yojson docs =
    Meilisearch_lwt.Document.add_documents conn ~index_uid to_yojson docs

  let get_document conn index_uid document_uid =
    Meilisearch_lwt.Document.get_document conn ~index_uid ~document_uid

  let delete_document conn index_uid document_uid =
    Meilisearch_lwt.Document.delete_document conn ~index_uid ~document_uid

  let search_term conn index_uid q =
    Meilisearch_lwt.Search.search_term conn ~index_uid ~q
end

open Lwt.Syntax

let free () =
  print_endline "Serialization tests finished.";
  Lwt.return ()

let test_wrong_hostname switch () =
  Lwt_switch.add_hook (Some switch) free;
  let* conn = Common.connect "http://not_an_actual_ms_de.st" "" in
  match conn with
  | Ok _ -> Alcotest.fail "Shouldn't have connected."
  | Error (`NotReachable _) -> Lwt.return_unit
  | Error e ->
      Alcotest.fail ("Wrong error unboxed: " ^ Meilisearch_lwt.error_to_string e)

let test_wrong_api_key switch () =
  Lwt_switch.add_hook (Some switch) free;
  let* conn_r = Common.connect (Common.url ()) (Common.invalid_api_key ()) in
  let conn =
    match conn_r with
    | Ok c -> c
    | Error e ->
        Alcotest.fail
          ("Should have connected: " ^ Meilisearch_lwt.error_to_string e)
  in
  let* task_r = Common.get_task conn 0 in
  match task_r with
  | Error (`Forbidden _) -> Lwt.return_unit
  | Ok _ -> Alcotest.fail "Should not have the permission."
  | Error e ->
      Alcotest.fail
        ("Wrong error unboxed: " ^ Meilisearch_lwt.Task.error_to_string e)

let test_wrong_task_uid switch () =
  Lwt_switch.add_hook (Some switch) free;
  let* conn = Common.get_configured_connection () in
  let* task_r = Common.get_task conn 5555 in
  match task_r with
  | Ok _ -> Alcotest.fail "Should have found task 5555"
  | Error e ->
      Alcotest.(check string)
        "Error NoSuchTask" "Task `5555` not found."
        (Meilisearch_lwt.Task.error_to_string e)
      |> Lwt.return

let test_wrong_index_uid switch () =
  Lwt_switch.add_hook (Some switch) free;
  let* conn = Common.get_configured_connection () in
  let* index_r = Common.get_index conn "test_index" in
  match index_r with
  | Ok _ -> Alcotest.fail "Shouldn't find test_index."
  | Error e ->
      Alcotest.(check string)
        "Index not found message" "No such index: test_index"
        (Meilisearch_lwt.Index.error_to_string e)
      |> Lwt.return

let test_index_creation switch () =
  Lwt_switch.add_hook (Some switch) free;
  let* conn = Common.get_configured_connection () in
  let* task_r = Common.create_index conn "test_index" "id" in
  let task_id =
    match task_r with
    | Ok i -> i
    | Error e ->
        Alcotest.fail
          ("Should have had gotten the task id: "
          ^ Meilisearch_lwt.Index.error_to_string e)
  in
  let* task_c = Common.wait_task conn task_id in
  match task_c with
  | Ok t ->
      Alcotest.(check string)
        "Status check for index creation" "succeeded"
        (Meilisearch_lwt.Task.task_status_to_string t.status)
      |> Lwt.return
  | Error e ->
      Alcotest.fail
        ("Task should have succeeded: " ^ Meilisearch_lwt.Task.error_to_string e)

let test_index_deletion switch () =
  Lwt_switch.add_hook (Some switch) free;
  let* conn = Common.get_configured_connection () in
  let* task_r = Common.delete_index conn "test_index" in
  let task_id =
    match task_r with
    | Ok i -> i
    | Error e ->
        Alcotest.fail
          ("Should have had gotten the task id: "
          ^ Meilisearch_lwt.Index.error_to_string e)
  in
  let* task_c = Common.wait_task conn task_id in
  match task_c with
  | Ok t ->
      Alcotest.(check string)
        "Status check for index deletion" "succeeded"
        (Meilisearch_lwt.Task.task_status_to_string t.status)
      |> Lwt.return
  | Error e ->
      Alcotest.fail
        ("Task should have succeeded: " ^ Meilisearch_lwt.Task.error_to_string e)

type document = {
  id : int;
  excerpt : string;
  tags : string list;
  title : string;
}
[@@deriving yojson]

let test_add_document switch () =
  Lwt_switch.add_hook (Some switch) free;
  let* conn = Common.get_configured_connection () in
  let doc =
    {
      id = 0;
      excerpt = "This is a simple document.";
      tags = [ "doc"; "text-only" ];
      title = "Main document.";
    }
  in
  let* task_r = Common.add_document conn "test_index" document_to_yojson doc in
  let task_uid =
    match task_r with
    | Ok t -> t
    | Error e ->
        Alcotest.fail
          (Printf.sprintf "Error while adding doc: %s\n"
             (Meilisearch_lwt.Document.error_to_string e))
  in
  let* task_c =
    Meilisearch_lwt.Task.wait_task conn ~max_attempts:50 ~delay:0.2 task_uid
  in
  match task_c with
  | Ok t ->
      Alcotest.(check string)
        "Status check for index creation" "succeeded"
        (Meilisearch_lwt.Task.task_status_to_string t.status)
      |> Lwt.return
  | Error e ->
      Alcotest.fail
        ("Could not add document: " ^ Meilisearch_lwt.Task.error_to_string e)

let test_add_documents switch () =
  Lwt_switch.add_hook (Some switch) free;
  let* conn = Common.get_configured_connection () in
  let doc_1 =
    {
      id = 1;
      excerpt = "This is the second document.";
      tags = [ "doc"; "text-only" ];
      title = "Second document.";
    }
  in
  let doc_2 =
    {
      id = 2;
      excerpt = "This is the third document.";
      tags = [ "doc"; "text-only" ];
      title = "Third document.";
    }
  in
  let docs = [ doc_1; doc_2 ] in
  let* task_r =
    Common.add_documents conn "test_index" document_to_yojson docs
  in
  let task_uid =
    match task_r with
    | Ok t -> t
    | Error e ->
        Alcotest.fail
          (Printf.sprintf "Error while adding doc: %s\n"
             (Meilisearch_lwt.Document.error_to_string e))
  in
  let* task_c =
    Meilisearch_lwt.Task.wait_task conn ~max_attempts:50 ~delay:0.2 task_uid
  in
  match task_c with
  | Ok t ->
      Alcotest.(check string)
        "Status check for index creation" "succeeded"
        (Meilisearch_lwt.Task.task_status_to_string t.status)
      |> Lwt.return
  | Error e ->
      Alcotest.fail
        ("Could not add document: " ^ Meilisearch_lwt.Task.error_to_string e)

let verify_document_0 doc =
  let document = document_of_yojson doc in
  match document with
  | Ok d ->
      Alcotest.(check string) "Should claim document 0" "Main document." d.title
      |> Lwt.return
  | Error e -> Alcotest.fail ("Could not deserialize document 0: " ^ e)

let test_get_document switch () =
  Lwt_switch.add_hook (Some switch) free;
  let* conn = Common.get_configured_connection () in
  let* document_r = Common.get_document conn "test_index" "0" in
  match document_r with
  | Ok d -> verify_document_0 d
  | Error e ->
      Alcotest.fail
        ("Could not get document 0: "
        ^ Meilisearch_lwt.Document.error_to_string e)

let test_delete_documents switch () =
  Lwt_switch.add_hook (Some switch) free;
  let* conn = Common.get_configured_connection () in
  let* task_r = Common.delete_document conn "test_index" "0" in
  let task_uid =
    match task_r with
    | Ok t -> t
    | Error e ->
        Alcotest.fail
          ("Could not get the task uid: "
          ^ Meilisearch_lwt.Document.error_to_string e)
  in
  let* task_c =
    Meilisearch_lwt.Task.wait_task conn ~max_attempts:50 ~delay:0.2 task_uid
  in
  match task_c with
  | Ok t ->
      Alcotest.(check string)
        "Status check for index creation" "succeeded"
        (Meilisearch_lwt.Task.task_status_to_string t.status)
      |> Lwt.return
  | Error e ->
      Alcotest.fail
        ("Could not wait for task to finish: "
        ^ Meilisearch_lwt.Task.error_to_string e)

module Q = Meilisearch_lwt.Search.Query

let test_search_doc switch () =
  Lwt_switch.add_hook (Some switch) free;
  let* conn = Common.get_configured_connection () in
  let* search_results_r = Common.search_term conn "test_index" "Second" in
  match search_results_r with
  | Ok _ -> Lwt.return_unit
  | Error e ->
      Alcotest.fail
        ("No search results for `Second`: "
        ^ Meilisearch_lwt.Search.error_to_string e)

module R = Meilisearch_lwt.Search.Result

let check_second_document doc =
  let document_yojson = document_of_yojson doc in
  let document =
    match document_yojson with
    | Ok d -> d
    | Error e -> Alcotest.fail ("Could not deserialize document: " ^ e)
  in
  Alcotest.(check int) "Primary key verification" 1 document.id;
  Alcotest.(check string)
    "Excerpt verification" "This is the second document." document.excerpt;
  Alcotest.(check (list string))
    "Tags verifcation" [ "doc"; "text-only" ] document.tags;
  Alcotest.(check string) "Title verification" "Second document." document.title
  |> Lwt.return

let verify_hits_in_results results =
  let unboxed_results = R.of_yojson results in
  let results =
    match unboxed_results with
    | Ok r -> r
    | Error e -> Alcotest.fail ("Could not unbox the results: " ^ e)
  in
  let hits = R.hits results in
  Alcotest.(check int) "Only 1 result for `Second`" 1 (List.length hits);
  match hits with
  | [ x ] -> check_second_document x
  | _ -> Alcotest.fail "Too many results from Meilisearch for `Second`"

let test_read_search_hits switch () =
  Lwt_switch.add_hook (Some switch) free;
  let* conn = Common.get_configured_connection () in
  let* search_results_r = Common.search_term conn "test_index" "Second" in
  match search_results_r with
  | Ok r -> verify_hits_in_results r
  | Error e ->
      Alcotest.fail
        ("No search results for `Second`: "
        ^ Meilisearch_lwt.Search.error_to_string e)

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "Integration tests suite."
       [
         ( "Connection & Permission failures",
           [
             Alcotest_lwt.test_case "Connecting to a wrong host"        `Quick test_wrong_hostname;
             Alcotest_lwt.test_case "Requesting task with a wrong key"  `Quick test_wrong_api_key;
           ] );
         ( "Tasks failures",
           [
             Alcotest_lwt.test_case "Connecting to a wrong host" `Quick test_wrong_task_uid;
           ] );
         ( "Index creation and failures",
           [
             Alcotest_lwt.test_case "Getting an inexisting index"       `Quick test_wrong_index_uid;
             Alcotest_lwt.test_case "Getting a newly created index"     `Quick test_index_creation;
           ] );
         ( "Documents APIs",
           [
             Alcotest_lwt.test_case "Add a single document"     `Quick test_add_document;
             Alcotest_lwt.test_case "Add multiple documents"    `Quick test_add_documents;
             Alcotest_lwt.test_case "Get a document"            `Quick test_get_document;
             Alcotest_lwt.test_case "Delete documents"          `Quick test_delete_documents;
           ] );
         ( "Search & Results",
           [
             Alcotest_lwt.test_case "Searching by term."        `Quick test_search_doc;
             Alcotest_lwt.test_case "Reading the results."      `Quick test_read_search_hits;
           ] );
         ( "Index deletion",
           [
             Alcotest_lwt.test_case "Deleting the test index" `Quick test_index_deletion;
           ] );
       ]
