(** Meilisearch_lwt provides asynchronous OCaml bindings for the Meilisearch
    HTTP API, using [Lwt] and [Cohttp].

    The library is designed around explicit error handling using polymorphic
    variants. *)

(** {1 Shared types and functions} *)

type t = Meilisearch_client.t
(** The abstract type representing the client, containing the URL and API key to
    the server. *)

type connection_error = [ Meilisearch_error.t | `NotReachable of string ]
(** Errors that can occur in this module: initialization, health check, and also
    network/system errors. *)

val connect : url:string -> key:string -> (t, connection_error) result Lwt.t
(** [connect ~url ~key] initializes a new Meilisearch client and immediately
    performs a health check against the [/health] endpoint of the instance. *)

val health : t -> (string, connection_error) result Lwt.t
(** [health client] checks the availability of the instance. Should return the
    only field of the response in case of success: "available". *)

val version : t -> (string, connection_error) result Lwt.t
(** [version client] returns the version JSON object of the instance. It
    contains the following string fields: commitSha, commitDate, pkgVersion. *)

val error_to_string : connection_error -> string
(** [error_to_string error] converts the polymorphic error variant of this
    module into a human-readable string. *)

(** {1 Submodules} *)

module Task = Meilisearch_task
(** Module for monitoring tasks. Many of the modules described below return a
    task ID; the Task submodule provides helpers to wait for or check these
    tasks. *)

module Index = Meilisearch_index
(** Module for basic index management. Provides APIs to get, create, and delete
    indexes; requires an API key with elevated privileges. *)

module Document = Meilisearch_document
(** Module for basic document management. Provides APIs to insert and delete
    documents. There is no format checking for these APIs; you provide
    Yojson.Safe.t formatted documents and send them to the Meilisearch instance.
*)

module Search = Meilisearch_search
(** Module to perform searches on a Meilisearch instance. Provides helpers for
    the different types of searches. *)

module Settings = Meilisearch_settings
(** Module to update basic (think absolute minimum) settings of indexes. You can
    use helpers or send raw settings (JSON). *)

module Error = Meilisearch_error
(** Module that shares the common error for other logical units. Such errors are
    network errors, serialization errors etc, you should always use the logical
    error_to_string, the one offered there is incomplete, but since we share the
    ms_api_error record, it can help you get more precision with the error
    message. *)
