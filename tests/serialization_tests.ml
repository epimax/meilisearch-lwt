module To_test = struct
  let valid_ms_task_deserialization () =
    let ms_task =
      {|
    {
       "batchUid" : 1,
       "canceledBy" : null,
       "details" : {
          "primaryKey" : "id"
       },
       "duration" : "PT0.014566068S",
       "enqueuedAt" : "2026-06-03T15:48:31.945600823Z",
       "error" : null,
       "finishedAt" : "2026-06-03T15:48:31.963862316Z",
       "indexUid" : "movies",
       "startedAt" : "2026-06-03T15:48:31.949296248Z",
       "status" : "succeeded",
       "type" : "indexCreation",
       "uid" : 1
    }
  |}
    in
    ms_task |> Yojson.Safe.from_string |> Meilisearch_lwt.Task.task_of_yojson

  let corrupt_ms_task_deserialization () =
    let ms_task = {|
    {
       "batchUid" : 1
    }
  |} in
    ms_task |> Yojson.Safe.from_string |> Meilisearch_lwt.Task.task_of_yojson

  let valid_ms_error_deserializaiton () =
    let ms_json_error =
      {|
      {
         "code" : "task_not_found",
         "link" : "https://docs.meilisearch.com/errors#task_not_found",
         "message" : "Task `424242` not found.",
         "type" : "invalid_request"
      }
    |}
    in
    ms_json_error |> Yojson.Safe.from_string
    |> Meilisearch_lwt.Error.ms_api_error_of_yojson

  let valid_ms_index_deserializaiton () =
    let ms_json_error =
      {|
      {
         "createdAt" : "2026-06-03T15:48:31.949432948Z",
         "primaryKey" : "id",
         "uid" : "movies",
         "updatedAt" : "2026-06-26T12:54:22.01089907Z"
      }
    |}
    in
    ms_json_error |> Yojson.Safe.from_string
    |> Meilisearch_lwt.Index.index_of_yojson
end

let task_eq (lhs : Meilisearch_lwt.Task.task) (rhs : Meilisearch_lwt.Task.task)
    =
  lhs.uid = rhs.uid

let task_pp fmt task =
  let task_str =
    task |> Meilisearch_lwt.Task.task_to_yojson |> Yojson.Safe.pretty_to_string
  in
  Format.fprintf fmt "%s\n" task_str

let task = Alcotest.testable task_pp task_eq

let test_deserialize_ms_task () =
  match To_test.valid_ms_task_deserialization () with
  | Error e -> Alcotest.fail e
  | Ok task ->
      Alcotest.(check int) "uid" 1 task.uid;
      Alcotest.(check string) "indexUid" "movies" task.indexUid;
      Alcotest.(check string)
        "status" "succeeded"
        (Meilisearch_lwt.Task.task_status_to_string task.status);
      Alcotest.(check (option string)) "canceledBy" None task.canceledBy

let test_deserialize_ms_error () =
  match To_test.valid_ms_error_deserializaiton () with
  | Error e -> Alcotest.fail e
  | Ok error ->
      Alcotest.(check string) "code" "task_not_found" error.code;
      Alcotest.(check string)
        "link" "https://docs.meilisearch.com/errors#task_not_found" error.link;
      Alcotest.(check string) "message" "Task `424242` not found." error.message;
      Alcotest.(check string) "type" "invalid_request" error.error_type

let test_deserialize_ms_index () =
  match To_test.valid_ms_index_deserializaiton () with
  | Error e -> Alcotest.fail e
  | Ok index ->
      Alcotest.(check string) "uid" "movies" index.uid;
      Alcotest.(check string) "primaryKey" "id" index.primaryKey

let test_deserialize_corrupt_ms_task () =
  match To_test.corrupt_ms_task_deserialization () with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "Payload could still be serialized."

let test_deserialize_corrupt_ms_task_2 () =
  let expected = Error "Meilisearch_task.task.finishedAt" in
  let actual = To_test.corrupt_ms_task_deserialization () in
  Alcotest.(check (result task string))
    "Made-up payload, deserialization should fail" expected actual

let () =
  let open Alcotest in
  run "Serialization tests suite"
    [
      ( "Valid JSON unboxing",
        [
          test_case "Deserialize MS (1.45) task"  `Quick test_deserialize_ms_task;
          test_case "Deserialize MS (1.45) error" `Quick test_deserialize_ms_error;
          test_case "Deserialize MS (1.45) index" `Quick test_deserialize_ms_index;
        ] );
      ( "Illegal JSON unboxing",
        [
          test_case "Deserialize corrupt MS (1.45) task"                `Quick test_deserialize_corrupt_ms_task;
          test_case "Deserialize corrupt MS (1.45) task - Check error"  `Quick test_deserialize_corrupt_ms_task_2;
        ] );
    ]
