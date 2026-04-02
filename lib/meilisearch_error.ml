type ms_api_error = {
  message : string;
  code : string;
  error_type : string; [@key "type"]
  link : string;
}
[@@deriving yojson]

type t =
  [ `BadRequest of string
  | `Unauthorized of string
  | `Forbidden of string
  | `NotFound of string
  | `SerializationError of string
  | `InvalidErrorResponse of string
  | `InternalError of string
  | `NotReachable of string ]

let error_to_string = function
  | `BadRequest _ ->
      "The request was unacceptable, often due to missing required parameter"
  | `Unauthorized _ -> "No valid API key provided"
  | `Forbidden _ ->
      "The API key doesn't have the permissions to perform the request"
  | `NotFound _ -> "The requested ressource doesn't exist"
  | `SerializationError e -> e
  | `InternalError e -> e
  | `InvalidErrorResponse e -> e
  | _ -> "Unknown error, try module error_to_string first"
