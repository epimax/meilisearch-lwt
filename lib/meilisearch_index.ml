open Lwt.Syntax

type index = {
  uid : string;
  primaryKey : string;
  createdAt : string;
  updatedAt : string;
}
[@@deriving yojson]

type index_creation = { uid : string; primaryKey : string } [@@deriving yojson]
type index_error = [ Meilisearch_error.t | `NoSuchIndex of string ]

let error_to_string = function
  | `NoSuchIndex i -> "No such index: " ^ i
  | #Meilisearch_error.t as e -> Meilisearch_error.error_to_string e

let map_network_error index_uid err =
  match err with
  | `BadRequest (err : Meilisearch_error.ms_api_error) ->
      `BadRequest err.message
  | `Unauthorized _ -> `Unauthorized "No valid API key provided"
  | `Forbidden _ ->
      `Forbidden "The API key doesn't have permission to perform request"
  | `NotFound _ -> `NoSuchIndex index_uid
  | `SerializationError e -> `SerializationError e
  | `InternalError e -> `InternalError e
  | `InvalidErrorResponse e -> `InvalidErrorResponse e
  | `NotReachable e -> `NotReachable e

let unbox_or_error_task resp =
  match Meilisearch_network.ms_post_resp_of_yojson resp with
  | Ok r -> Lwt_result.return r.taskUid
  | Error e -> Lwt_result.fail (`SerializationError e)

let create_index conn ~index_uid ~pk =
  let payload = { uid = index_uid; primaryKey = pk } in
  let payload_network = index_creation_to_yojson payload in
  let create_index_path = "/indexes" in
  let* res =
    Meilisearch_network.post_to_ms conn create_index_path payload_network
  in
  match res with
  | Ok t -> unbox_or_error_task t
  | Error e -> Lwt_result.fail (map_network_error index_uid e)

let delete_index conn ~index_uid =
  let delete_index_path = Printf.sprintf "/indexes/%s" index_uid in
  let* res = Meilisearch_network.delete_to_ms_task conn delete_index_path in
  match res with
  | Ok t -> unbox_or_error_task t
  | Error e -> Lwt_result.fail (map_network_error index_uid e)

let get_index conn ~index_uid =
  let get_index_path = Printf.sprintf "/indexes/%s" index_uid in
  let res =
    Meilisearch_network.get_and_decode conn get_index_path index_of_yojson
  in
  Lwt_result.map_error (map_network_error index_uid) res
