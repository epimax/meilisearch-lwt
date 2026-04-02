(** Implementation of the connection handler. *)

(** {1 Shared types and functions} *)

type t
(** The abstract type representing the client, containing the URL and API key to
    the server. *)

val create : url:string -> key:string -> t
(** [create ~url ~key] creates the connection record from the given URL and API
    key. *)

val url : t -> string
(** [url client] gets the URL, needed in all calls to the Meilisearch APIs. *)

val key : t -> string
(** [key client] gets the API key, needed in restricted calls to the Meilisearch
    APIs. *)
