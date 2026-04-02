open Lwt.Syntax

type document_error =
  [ Meilisearch_error.t | `NoSuchDocument of string | `NoSuchIndex of string ]

let map_network_error index_uid ?(document_uid = "") error =
  match error with
  | `BadRequest (err : Meilisearch_error.ms_api_error) ->
      `BadRequest err.message
  | `Unauthorized _ -> `Unauthorized "No valid API key provided"
  | `Forbidden _ ->
      `Forbidden "The API key doesn't have permission to perform request"
  | `NotFound (err : Meilisearch_error.ms_api_error)
    when err.code = "index_not_found" ->
      `NoSuchIndex index_uid
  | `NotFound _ -> `NoSuchDocument document_uid
  | `SerializationError e -> `SerializationError e
  | `InternalError e -> `InternalError e
  | `InvalidErrorResponse e -> `InvalidErrorResponse e
  | `NotReachable e -> `NotReachable e

let error_to_string = function
  | `NoSuchDocument d -> "No such document: " ^ d
  | `NoSuchIndex i -> "No such index: " ^ i
  | #Meilisearch_error.t as e -> Meilisearch_error.error_to_string e

let unbox_or_error_task resp =
  match Meilisearch_network.ms_post_resp_of_yojson resp with
  | Ok r -> Lwt_result.return r.taskUid
  | Error e -> Lwt_result.fail (`SerializationError e)

let add_documents conn ~index_uid to_json docs =
  let docs_payload = `List (List.map to_json docs) in
  let add_or_replace_path = Printf.sprintf "/indexes/%s/documents" index_uid in
  let* res =
    Meilisearch_network.post_to_ms conn add_or_replace_path docs_payload
  in
  match res with
  | Ok t -> unbox_or_error_task t
  | Error e -> Lwt_result.fail (map_network_error index_uid e)

let add_document conn ~index_uid to_json doc =
  add_documents conn ~index_uid to_json [ doc ]

let edit_documents conn ~index_uid to_json docs =
  let docs_payload = `List (List.map to_json docs) in
  let add_or_replace_path = Printf.sprintf "/indexes/%s/documents" index_uid in
  let* res =
    Meilisearch_network.put_to_ms conn add_or_replace_path docs_payload
  in
  match res with
  | Ok t -> unbox_or_error_task t
  | Error e -> Lwt_result.fail (map_network_error index_uid e)

let edit_document conn ~index_uid to_json doc =
  edit_documents conn ~index_uid to_json [ doc ]

let delete_document conn ~index_uid ~document_uid =
  let delete_doc_path =
    Printf.sprintf "/indexes/%s/documents/%s" index_uid document_uid
  in
  let* res = Meilisearch_network.delete_to_ms_task conn delete_doc_path in
  match res with
  | Ok t -> unbox_or_error_task t
  | Error e -> Lwt_result.fail (map_network_error index_uid ~document_uid e)

let get_document conn ~index_uid ~document_uid =
  let get_document_path =
    Printf.sprintf "/indexes/%s/documents/%s" index_uid document_uid
  in
  let res = Meilisearch_network.get_json conn get_document_path in
  Lwt_result.map_error (map_network_error index_uid ~document_uid) res
