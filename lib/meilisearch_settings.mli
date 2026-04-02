(** Helpers to manage your Meilisearch instance. Remember you'll need elevated
    privileges to do so. We provide a submodule {!Settings} for Index minimal
    recommended configuration. *)

(** {1 Submodule} *)
module Settings : sig
  type t

  val init : unit -> t
  val set_ranking_rules : string list -> t -> t
  val set_filterable_attributes : string list -> t -> t
  val set_searchable_attributes : string list -> t -> t
  val to_yojson : t -> Yojson.Safe.t
end
(** Similar to {!Search.Query}, this is a query builder for settings. Most
    settings are missing; the library provides the strict minimum. You can
    always use {!update_all_settings_raw} for additional settings. *)

(** {1 Shared types and functions} *)

type settings_error = [ Meilisearch_error.t | `NoSuchIndex of string ]
(** Errors that can occur in this module: index not found, and also
    network/system errors. *)

val list_all_settings :
  Meilisearch_client.t ->
  Meilisearch_index.index ->
  (Yojson.Safe.t, settings_error) result Lwt.t
(** [list_all_settings client index] returns a JSON object from Meilisearch
    listing all the current settings of the index. You need to provide an index
    record. *)

val update_all_settings :
  Meilisearch_client.t ->
  Meilisearch_index.index ->
  Settings.t ->
  (int, settings_error) result Lwt.t
(** [update_all_settings client index settings] updates the settings of an index
    with settings built from the submodule {!Settings}. You need to provide an
    index record. *)

val update_all_settings_raw :
  Meilisearch_client.t ->
  Meilisearch_index.index ->
  Yojson.Safe.t ->
  (int, settings_error) result Lwt.t
(** [update_all_settings_raw client index settings_raw] updates the settings of
    an index with settings_raw as a valid JSON object, with no checks performed
    on the library side. You need to provide an index record. *)

val delete_all_settings :
  Meilisearch_client.t ->
  Meilisearch_index.index ->
  (int, settings_error) result Lwt.t
(** [delete_all_settings client index] deletes all the settings of the given
    index. You need to provide an index record. *)

val error_to_string : settings_error -> string
(** [error_to_string error] converts the polymorphic error variant of this
    module into a human-readable string. *)
