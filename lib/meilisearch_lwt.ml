open Lwt.Syntax

type t = Meilisearch_client.t
type connection_error = [ Meilisearch_error.t | `NotReachable of string ]
type health_response = { status : string } [@@deriving yojson]

type version_response = {
  commitSha : string;
  commitDate : string;
  pkgVersion : string;
}
[@@deriving yojson]

let map_connection_error = function
  | `InternalError e -> `NotReachable e
  | `NotFound (err : Meilisearch_error.ms_api_error) -> `NotFound err.message
  | `Forbidden (err : Meilisearch_error.ms_api_error) -> `Forbidden err.message
  | `SerializationError e -> `SerializationError e
  | `BadRequest (err : Meilisearch_error.ms_api_error) ->
      `BadRequest err.message
  | `Unauthorized (err : Meilisearch_error.ms_api_error) ->
      `Unauthorized err.message
  | `InvalidErrorResponse e -> `InvalidErrorResponse e
  | `NotReachable e -> `NotReachable e

let error_to_string = function
  | `NotReachable e -> "Server is not reachable: " ^ e
  | #Meilisearch_error.t as e -> Meilisearch_error.error_to_string e

let health conn =
  let* health_r =
    Meilisearch_network.get_and_decode conn "/health" health_response_of_yojson
  in
  match health_r with
  | Ok h -> Lwt_result.return h.status
  | Error e -> Lwt_result.fail (map_connection_error e)

let connect ~url ~key =
  let conn = Meilisearch_client.create ~url ~key in
  Lwt.catch
    (fun () ->
      let* health_res = health conn in
      match health_res with
      | Ok h when h = "available" -> Lwt_result.return conn
      | Ok h ->
          Lwt_result.fail
            (`NotReachable ("Server returned non-available status: " ^ h))
      | Error e -> Lwt_result.fail e)
    (fun exn -> Lwt_result.fail (`NotReachable (Printexc.to_string exn)))

let version conn =
  let version_path = "/version" in
  let* res = Meilisearch_network.get_json conn version_path in
  match res with
  | Ok v -> Lwt_result.return (Yojson.Safe.to_string v)
  | Error e -> Lwt_result.fail (map_connection_error e)

module Task = Meilisearch_task
module Index = Meilisearch_index
module Document = Meilisearch_document
module Search = Meilisearch_search
module Settings = Meilisearch_settings
module Error = Meilisearch_error
