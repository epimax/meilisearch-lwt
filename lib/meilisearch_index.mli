(** Basic index management for Meilisearch. The library is primarily intended to
    retrieve data so this module provides basic helpers if you want to create an
    index. *)

(** {1 Shared types and functions} *)
type index = {
  uid : string;
  primaryKey : string;
  createdAt : string;
  updatedAt : string;
}
[@@deriving yojson]
(** Record that reflects the Meilisearch response to GET /indexes/index_uid. *)

type index_error = [ Meilisearch_error.t | `NoSuchIndex of string ]
(** Errors that can occur in this module: initialization, health check, and also
    network/system errors. *)

val create_index :
  Meilisearch_client.t ->
  index_uid:string ->
  pk:string ->
  (int, index_error) result Lwt.t
(** [create_index client ~index_uid ~pk] creates an index with the given uid and
    primary key. It is strongly recommended to update the settings before
    inserting documents on a new index. Asynchronous task, returns a task id
    when successful. *)

val delete_index :
  Meilisearch_client.t -> index_uid:string -> (int, index_error) result Lwt.t
(** [delete_index client ~index_uid] deletes an index with the given uid.
    Asynchronous task, returns a task id when successful. *)

val get_index :
  Meilisearch_client.t -> index_uid:string -> (index, index_error) result Lwt.t
(** [get_index client ~index_uid] gets an {!index} record with the given uid.
    Immediate request (not queued as an asynchronous task in Meilisearch),
    returns a filled index record. *)

val error_to_string : index_error -> string
(** [error_to_string error] converts the polymorphic error variant of this
    module into a human-readable string. *)
