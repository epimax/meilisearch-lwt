(** Search module of the library. We provide two submodules, Query and Result,
    to help building queries and reading results. There is no support for media
    search or enterprise-only functionality. *)

type search_error = [ Meilisearch_error.t | `NoSuchIndex of string ]
(** Errors that can occur in this module: index not found, and also
    network/system errors. *)

(** {1 Submodules} *)
module Query : sig
  type t
  type matching_strategy_param = [ `Last | `All | `Frequency ]

  val init : unit -> t
  val add_query : string -> t -> t
  val add_offset : ?value:int -> t -> t
  val add_limit : ?value:int -> t -> t
  val add_page : int -> t -> t
  val add_hits_per_page : int -> t -> t
  val add_attributes_to_retrieve : string list -> t -> t
  val add_attributes_to_crop : string list -> t -> t
  val add_crop_length : ?value:int -> t -> t
  val add_crop_marker : ?value:string -> t -> t
  val add_attributes_to_highlight : string list -> t -> t
  val add_highlight_pre_tag : ?value:string -> t -> t
  val add_highlight_post_tag : ?value:string -> t -> t
  val add_show_matches_position : bool -> t -> t
  val add_filter : string -> t -> t
  val add_filters : string list -> t -> t
  val add_sort : string list -> t -> t
  val add_distinct : string -> t -> t
  val add_facets : string list -> t -> t
  val add_matching_strategy : matching_strategy_param -> t -> t
  val add_attributes_to_search_on : string list -> t -> t
  val add_ranking_score_threshold : float -> t -> t
  val add_locales : string list -> t -> t
  val add_hybrid : ?embedder:string -> ?semantic_ratio:float -> t -> t
  val add_vector : float list -> t -> t
  val add_retrieve_vectors : bool -> t -> t
  val add_personalize : user_context:string -> t -> t
  val add_use_network : bool -> t -> t
  val add_show_ranking_score : bool -> t -> t
  val add_show_ranking_score_details : bool -> t -> t
  val add_show_performance_details : bool -> t -> t
  val to_yojson : t -> Yojson.Safe.t
end
(** See README and examples/ for suggested workflow. If you have a basic query
    to do, using this module can be easier than preparing your own derivable
    record. *)

module Result : sig
  type t

  val of_yojson : Yojson.Safe.t -> (t, string) result
  val hits : t -> Yojson.Safe.t list
  val estimated_total_hits : t -> int
  val processing_time_ms : t -> int
  val query : t -> string
end

(** See examples/ for suggested workflows. Since the response from Meilisearch
    changes depending on your query, we provide this module that reads the JSON
    manually to give you back the [hits] field and other mandatory fields from
    the response. Since the library doesn't enforce any schema validation on the
    documents you insert, it doesn't help you read the results either. You can
    define your own derivable record that reads the [hits] field elements, or
    read them manually. *)

val search_term :
  Meilisearch_client.t ->
  index_uid:string ->
  q:string ->
  (Yojson.Safe.t, search_error) result Lwt.t
(** [search_term client ~index_uid ~q] sends a simple term search to your
    instance. This is a GET request to Meilisearch that looks in every
    searchableAttributes of your document. *)

val search_post :
  Meilisearch_client.t ->
  index_uid:string ->
  Query.t ->
  (Yojson.Safe.t, search_error) result Lwt.t
(** [search_post client ~index_uid query] sends a structured search to your
    instance. This is a POST request to Meilisearch. The query should be built
    with the submodule {!Query}. *)

val search_post_raw :
  Meilisearch_client.t ->
  index_uid:string ->
  Yojson.Safe.t ->
  (Yojson.Safe.t, search_error) result Lwt.t
(** [search_post_raw client ~index_uid query] sends a raw structured search to
    your instance. This is a POST request to Meilisearch. The query is a JSON
    object built by yourself that represents a valid request to Meilisearch,
    with no checks performed on the library side. *)

val search_term_idx :
  Meilisearch_client.t ->
  Meilisearch_index.index ->
  q:string ->
  (Yojson.Safe.t, search_error) result Lwt.t
(** [search_term_idx client index ~q] sends a simple term search to your
    instance. The [_idx] APIs use the internal {!Meilisearch_lwt.Index.index} record
    to ensure the index exists on your instance. This is a GET request to
    Meilisearch that looks in every searchableAttributes of your document. *)

val search_post_idx :
  Meilisearch_client.t ->
  Meilisearch_index.index ->
  Query.t ->
  (Yojson.Safe.t, search_error) result Lwt.t
(** [search_post_idx client index query] sends a structured search to your
    instance. The [_idx] APIs use the internal {!Meilisearch_lwt.Index.index} record
    to ensure the index exists on your instance. This is a POST request to
    Meilisearch. The query should be built with the submodule {!Query}. *)

val search_post_raw_idx :
  Meilisearch_client.t ->
  Meilisearch_index.index ->
  Yojson.Safe.t ->
  (Yojson.Safe.t, search_error) result Lwt.t
(** [search_post_raw_idx client index query] sends a raw structured search to
    your instance. The [_idx] APIs use the internal {!Meilisearch_lwt.Index.index}
    record to ensure the index exists on your instance. This is a POST request
    to Meilisearch. The query is a JSON object built by yourself that represents
    a valid request to Meilisearch, with no checks performed on the library
    side. *)

val error_to_string : search_error -> string
(** [error_to_string error] converts the polymorphic error variant of this
    module into a human-readable string. *)
