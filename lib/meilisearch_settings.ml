open Lwt.Syntax

type settings_error = [ Meilisearch_error.t | `NoSuchIndex of string ]

let map_network_error index_uid error =
  match error with
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

module Settings = struct
  module J = Meilisearch_json

  type t = J.t

  let init () : t = J.init ()
  let set_ranking_rules rules s = J.add_param_string_list "rankingRules" rules s

  let set_filterable_attributes filterable_attributes s =
    J.add_param_string_list "filterableAttributes" filterable_attributes s

  let set_searchable_attributes searchable_attributes s =
    J.add_param_string_list "searchableAttributes" searchable_attributes s

  let to_yojson s = J.to_yojson s
end

let error_to_string = function
  | `NoSuchIndex i -> "No such index: " ^ i
  | #Meilisearch_error.t as e -> Meilisearch_error.error_to_string e

let unbox_or_error_task resp =
  match Meilisearch_network.ms_post_resp_of_yojson resp with
  | Ok r -> Lwt_result.return r.taskUid
  | Error e -> Lwt_result.fail (`SerializationError e)

let list_all_settings conn (index : Meilisearch_index.index) =
  let list_settings_path = Printf.sprintf "/indexes/%s/settings" index.uid in
  let res = Meilisearch_network.get_json conn list_settings_path in
  Lwt_result.map_error (map_network_error index.uid) res

let update_all_settings conn (index : Meilisearch_index.index) settings =
  let update_settings_path = Printf.sprintf "/indexes/%s/settings" index.uid in
  let* res =
    Meilisearch_network.patch_to_ms conn update_settings_path
      (Settings.to_yojson settings)
  in
  match res with
  | Ok t -> unbox_or_error_task t
  | Error e -> Lwt_result.fail (map_network_error index.uid e)

let update_all_settings_raw conn (index : Meilisearch_index.index) settings =
  let update_settings_path = Printf.sprintf "/indexes/%s/settings" index.uid in
  let* res =
    Meilisearch_network.patch_to_ms conn update_settings_path settings
  in
  match res with
  | Ok t -> unbox_or_error_task t
  | Error e -> Lwt_result.fail (map_network_error index.uid e)

let delete_all_settings conn (index : Meilisearch_index.index) =
  let list_settings_path = Printf.sprintf "/indexes/%s/settings" index.uid in
  let* res = Meilisearch_network.delete_to_ms_task conn list_settings_path in
  match res with
  | Ok t -> unbox_or_error_task t
  | Error e -> Lwt_result.fail (map_network_error index.uid e)
