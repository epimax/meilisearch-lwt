(** Error handling module for Meilisearch API responses and client errors. *)

type t =
  [ `BadRequest of string
  | `Unauthorized of string
  | `Forbidden of string
  | `NotFound of string
  | `SerializationError of string
  | `InvalidErrorResponse of string
  | `InternalError of string
  | `NotReachable of string ]
(** Polymorphic variants representing different categories of errors encountered
    by the client. *)

type ms_api_error = {
  message : string;
  code : string;
  error_type : string; [@key "type"]
  link : string;
}
[@@deriving yojson]
(** Detailed error representation returned by the Meilisearch API. *)

val error_to_string : t -> string
(** [error_to_string error] converts an error variant into a human-readable
    string. *)
