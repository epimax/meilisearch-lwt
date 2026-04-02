open Lwt.Syntax

type task_status = Enqueued | Processing | Succeeded | Failed | Canceled

let task_status_to_yojson = function
  | Enqueued -> `String "enqueued"
  | Processing -> `String "processing"
  | Succeeded -> `String "succeeded"
  | Failed -> `String "failed"
  | Canceled -> `String "canceled"

let task_status_of_yojson = function
  | `String "enqueued" -> Ok Enqueued
  | `String "processing" -> Ok Processing
  | `String "succeeded" -> Ok Succeeded
  | `String "failed" -> Ok Failed
  | `String "canceled" -> Ok Canceled
  | j ->
      Error (Printf.sprintf "Unknown task status: %s" (Yojson.Safe.to_string j))

let task_status_to_string = function
  | Enqueued -> "enqueued"
  | Processing -> "processing"
  | Succeeded -> "succeeded"
  | Failed -> "failed"
  | Canceled -> "canceled"

type task = {
  batchUid : int option; [@default None]
  uid : int;
  indexUid : string;
  status : task_status;
  tasktype : string; [@key "type"]
  canceledBy : string option;
  details : Yojson.Safe.t;
  error : Yojson.Safe.t option;
  duration : string option;
  enqueuedAt : string;
  startedAt : string option;
  finishedAt : string option;
}
[@@deriving yojson]

type task_error =
  [ Meilisearch_error.t
  | `NoSuchTask of string
  | `TaskFailed of string
  | `TaskCanceled of string
  | `Timeout of task ]

let map_network_error = function
  | `NotFound (err : Meilisearch_error.ms_api_error) -> `NoSuchTask err.message
  | `Forbidden (err : Meilisearch_error.ms_api_error) -> `Forbidden err.message
  | `Unauthorized (err : Meilisearch_error.ms_api_error) ->
      `Unauthorized err.message
  | `SerializationError e -> `SerializationError e
  | `InternalError e -> `InternalError e
  | `NotReachable e -> `NotReachable e
  | `BadRequest (err : Meilisearch_error.ms_api_error) ->
      `BadRequest err.message
  | `InvalidErrorResponse e -> `InvalidErrorResponse e

let error_to_string = function
  | `NoSuchTask e -> e
  | `TaskFailed e -> "Task failed: " ^ e
  | `TaskCanceled e -> "Task canceled: " ^ e
  | `Timeout (e : task) ->
      Printf.sprintf "Wait for task timeout, check the task details: %s"
        (Yojson.Safe.pretty_to_string e.details)
  | #Meilisearch_error.t as e -> Meilisearch_error.error_to_string e

let get_task conn ~task_uid =
  let get_task_path = Printf.sprintf "/tasks/%s" (string_of_int task_uid) in
  let res =
    Meilisearch_network.get_and_decode conn get_task_path task_of_yojson
  in
  Lwt_result.map_error map_network_error res

let rec wait_task_completion conn attempt max_attempts delay task_path =
  let* task_ms_r =
    Meilisearch_network.get_and_decode conn task_path task_of_yojson
  in
  match task_ms_r with
  | Ok t -> parse_task_status conn attempt max_attempts delay task_path t
  | Error e -> Lwt_result.fail (map_network_error e)

and parse_task_status conn attempt max_attempts delay task_path task_ms =
  match task_ms.status with
  | Succeeded -> Lwt_result.return task_ms
  | Failed ->
      Lwt_result.fail
        (`TaskFailed "The task has failed, see details & error object")
  | Canceled ->
      Lwt_result.fail
        (`TaskCanceled "The task has been canceled, see details & error object")
  | Processing | Enqueued ->
      begin if attempt >= max_attempts then Lwt_result.fail (`Timeout task_ms)
      else
        let* _ = Lwt_unix.sleep delay in
        wait_task_completion conn (attempt + 1) max_attempts delay task_path
      end

let wait_task conn ?(max_attempts = 5) ~delay task_uid =
  let task_path = Printf.sprintf "/tasks/%s" (string_of_int task_uid) in
  wait_task_completion conn 0 max_attempts delay task_path

let return_task_status t = Lwt_result.return t.status

let check_task conn ~task_uid =
  let get_task_path = Printf.sprintf "/tasks/%s" (string_of_int task_uid) in
  let* task_r =
    Meilisearch_network.get_and_decode conn get_task_path task_of_yojson
  in
  match task_r with
  | Ok t -> return_task_status t
  | Error e -> Lwt_result.fail (map_network_error e)
