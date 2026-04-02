(** Documents are treated as Yojson.Safe.t. This module helps you manage such
    data on your Meilisearch instances. *)

(** {1 Shared types and functions} *)

type document_error =
  [ Meilisearch_error.t | `NoSuchDocument of string | `NoSuchIndex of string ]
(** Errors that can occur in this module: non-existent document/index, and also
    network/system errors. *)

val add_document :
  Meilisearch_client.t ->
  index_uid:string ->
  ('a -> Yojson.Safe.t) ->
  'a ->
  (int, document_error) result Lwt.t
(** [add_document client ~index_uid f doc] sends a single document [doc] to the
    index [index_uid]. [f] is your generated to_yojson function, needed to build
    the request body. Asynchronous task, returns a task id when successful. *)

val add_documents :
  Meilisearch_client.t ->
  index_uid:string ->
  ('a -> Yojson.Safe.t) ->
  'a list ->
  (int, document_error) result Lwt.t
(** [add_documents client ~index_uid f docs] sends multiple documents [docs] to
    the index [index_uid]. [f] is your generated to_yojson function, needed to
    build the request body. Asynchronous task, returns a task id when
    successful. *)

val edit_document :
  Meilisearch_client.t ->
  index_uid:string ->
  ('a -> Yojson.Safe.t) ->
  'a ->
  (int, document_error) result Lwt.t
(** [edit_document client ~index_uid f doc] edits a document [doc] on the index
    [index_uid]. [f] is your generated to_yojson function, needed to build the
    request body. Asynchronous task, returns a task id when successful. *)

val edit_documents :
  Meilisearch_client.t ->
  index_uid:string ->
  ('a -> Yojson.Safe.t) ->
  'a list ->
  (int, document_error) result Lwt.t
(** [edit_documents client ~index_uid f docs] edits multiple documents [docs] on
    the index [index_uid]. [f] is your generated to_yojson function, needed to
    build the request body. Asynchronous task, returns a task id when
    successful. *)

val delete_document :
  Meilisearch_client.t ->
  index_uid:string ->
  document_uid:string ->
  (int, document_error) result Lwt.t
(** [delete_document client ~index_uid ~document_uid] deletes a document using
    its ID (primary key). Asynchronous task, returns a task id when successful.
*)

val get_document :
  Meilisearch_client.t ->
  index_uid:string ->
  document_uid:string ->
  (Yojson.Safe.t, document_error) result Lwt.t
(** [get_document client ~index_uid ~document_uid] gets a document using its ID
    (primary key). Immediate request (not queued as an asynchronous task in
    Meilisearch), returns the document when present on the instance. *)

val error_to_string : document_error -> string
(** [error_to_string error] converts the polymorphic error variant of this
    module into a human-readable string. *)
