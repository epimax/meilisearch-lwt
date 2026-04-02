module Query = struct
  module J = Meilisearch_json

  type t = Meilisearch_json.t

  type hybrid = { embedder : string; semantic_ratio : float }
  [@@deriving yojson]

  type personalize = { user_context : string } [@@deriving yojson]
  type matching_strategy_param = [ `Last | `All | `Frequency ]

  let matching_strategy_param_to_string = function
    | `Last -> "last"
    | `All -> "all"
    | `Frequency -> "frequency"

  let init () : t = J.init ()
  let add_query value query = J.add_param_string "q" value query
  let add_offset ?(value = 0) query = J.add_param_int "offset" value query
  let add_limit ?(value = 20) query = J.add_param_int "limit" value query
  let add_page value query = J.add_param_int "page" value query
  let add_hits_per_page value query = J.add_param_int "hitsPerPage" value query

  let add_attributes_to_retrieve values query =
    J.add_param_string_list "attributesToRetrieve" values query

  let add_attributes_to_crop values query =
    J.add_param_string_list "attributesToCrop" values query

  let add_crop_length ?(value = 10) query =
    J.add_param_int "cropLength" value query

  let add_crop_marker ?(value = "") query =
    J.add_param_string "cropMarker" value query

  let add_attributes_to_highlight values query =
    J.add_param_string_list "attributesToHighlight" values query

  let add_highlight_pre_tag ?(value = "<em>") query =
    J.add_param_string "highlightPreTag" value query

  let add_highlight_post_tag ?(value = "</em>") query =
    J.add_param_string "highlightPostTag" value query

  let add_show_matches_position value query =
    J.add_param_bool "showMatchesPosition" value query

  let add_filter value query = J.add_param_string "filter" value query
  let add_filters values query = J.add_param_string_list "filter" values query
  let add_sort value query = J.add_param_string_list "sort" value query
  let add_distinct value query = J.add_param_string "distinct" value query
  let add_facets value query = J.add_param_string_list "facets" value query

  let add_matching_strategy value query =
    J.add_param_string "matchingStrategy"
      (matching_strategy_param_to_string value)
      query

  let add_attributes_to_search_on values query =
    J.add_param_string_list "attributesToSearchOn" values query

  let add_ranking_score_threshold value query =
    match value with
    | v when v >= 0.0 && v <= 1.0 ->
        J.add_param_float "rankingScoreThreshold" value query
    | _ -> failwith "Treshold must be in range [0.0:1.0]"

  let add_locales values query = J.add_param_string_list "locales" values query

  let add_hybrid ?(embedder = "") ?(semantic_ratio = 0.5) query =
    let hybrid_obj = { embedder; semantic_ratio } in
    J.add_param_obj hybrid_to_yojson "hybrid" hybrid_obj query

  let add_vector values query = J.add_param_float_list "vector" values query

  let add_retrieve_vectors value query =
    J.add_param_bool "retrieveVectors" value query

  let add_personalize ~user_context query =
    let personalize_obj = { user_context } in
    J.add_param_obj personalize_to_yojson "personalize" personalize_obj query

  let add_use_network value query = J.add_param_bool "useNetwork" value query

  let add_show_ranking_score value query =
    J.add_param_bool "showRankingScore" value query

  let add_show_ranking_score_details value query =
    J.add_param_bool "showRankingScoreDetails" value query

  let add_show_performance_details value query =
    J.add_param_bool "showPerformanceDetails" value query

  let to_yojson q = J.to_yojson q
end

module Result = struct
  type t = {
    query : string;
    hits : Yojson.Safe.t list;
    estimatedTotalHits : int;
    processingTimeMs : int;
  }

  let of_yojson json =
    let open Yojson.Safe.Util in
    try
      let query = json |> member "query" |> to_string in
      let hits = json |> member "hits" |> to_list in
      let estimatedTotalHits = json |> member "estimatedTotalHits" |> to_int in
      let processingTimeMs = json |> member "processingTimeMs" |> to_int in
      Ok { query; hits; estimatedTotalHits; processingTimeMs }
    with
    | Type_error (e, _) -> Error e
    | Undefined (e, _) -> Error e
    | Yojson.Json_error e -> Error e

  let hits resp = resp.hits
  let estimated_total_hits resp = resp.estimatedTotalHits
  let processing_time_ms resp = resp.processingTimeMs
  let query resp = resp.query
end

type search_error = [ Meilisearch_error.t | `NoSuchIndex of string ]

let error_to_string = function
  | `NoSuchIndex i -> "No such index: " ^ i
  | #Meilisearch_error.t as e -> Meilisearch_error.error_to_string e

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
  | `InvalidErrorResponse e -> `InternalError e
  | `NotReachable e -> `NotReachable e

let search_term (conn : Meilisearch_client.t) ~(index_uid : string)
    ~(q : string) =
  let search_path = Printf.sprintf "/indexes/%s/search?q=%s" index_uid q in
  let res = Meilisearch_network.get_json conn search_path in
  Lwt_result.map_error (map_network_error index_uid) res

let search_post (conn : Meilisearch_client.t) ~(index_uid : string) q =
  let search_path = Printf.sprintf "/indexes/%s/search" index_uid in
  let res =
    Meilisearch_network.post_to_ms conn search_path (Query.to_yojson q)
  in
  Lwt_result.map_error (map_network_error index_uid) res

let search_post_raw (conn : Meilisearch_client.t) ~(index_uid : string) q =
  let search_path = Printf.sprintf "/indexes/%s/search" index_uid in
  let res = Meilisearch_network.post_to_ms conn search_path q in
  Lwt_result.map_error (map_network_error index_uid) res

let search_term_idx (conn : Meilisearch_client.t)
    (index : Meilisearch_index.index) ~(q : string) =
  let search_path = Printf.sprintf "/indexes/%s/search?q=%s" index.uid q in
  let res = Meilisearch_network.get_json conn search_path in
  Lwt_result.map_error (map_network_error index.uid) res

let search_post_idx (conn : Meilisearch_client.t)
    (index : Meilisearch_index.index) q =
  let search_path = Printf.sprintf "/indexes/%s/search" index.uid in
  let res =
    Meilisearch_network.post_to_ms conn search_path (Query.to_yojson q)
  in
  Lwt_result.map_error (map_network_error index.uid) res

let search_post_raw_idx (conn : Meilisearch_client.t)
    (index : Meilisearch_index.index) q =
  let search_path = Printf.sprintf "/indexes/%s/search" index.uid in
  let res = Meilisearch_network.post_to_ms conn search_path q in
  Lwt_result.map_error (map_network_error index.uid) res
