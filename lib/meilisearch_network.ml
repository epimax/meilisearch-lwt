open Lwt.Syntax

type search_req_resp = {
  message : string;
  code : string;
  _type : string; [@key "type"]
  link : string;
}
[@@deriving yojson]

type ms_post_resp = {
  taskUid : int;
  indexUid : string option;
  status : string;
  task_type : string; [@key "type"]
  enqueuedAt : string;
}
[@@deriving yojson]

open Meilisearch_error

type ms_errors_http =
  [ `BadRequest of ms_api_error
  | `Unauthorized of ms_api_error
  | `Forbidden of ms_api_error
  | `NotFound of ms_api_error
  | `SerializationError of string
  | `InvalidErrorResponse of string
  | `InternalError of string ]

let make_header ~key =
  Cohttp.Header.init () |> fun h ->
  Cohttp.Header.add h "Authorization" ("Bearer " ^ key) |> fun h ->
  Cohttp.Header.add h "Content-Type" "application/json"

let make_body_f ~req f =
  f req |> Yojson.Safe.to_string |> Cohttp_lwt.Body.of_string

let make_body req = req |> Yojson.Safe.to_string |> Cohttp_lwt.Body.of_string

let make_ms_url conn endpoint =
  Meilisearch_client.url conn ^ endpoint |> Uri.of_string

let decode_body body f =
  Lwt.map
    (fun s -> Yojson.Safe.from_string s |> f)
    (Cohttp_lwt.Body.to_string body)

let body_to_yojson body =
  try
    let* body_str = Cohttp_lwt.Body.to_string body in
    Lwt_result.return (Yojson.Safe.from_string body_str)
  with
  | Yojson.Json_error e -> Lwt_result.fail (`SerializationError e)
  | _ ->
      Lwt_result.fail (`InvalidErrorResponse "Could not serialize MS response.")

let build_err err body =
  let* ms_error_res_p = Cohttp_lwt.Body.to_string body in
  let ms_error_res =
    ms_error_res_p |> Yojson.Safe.from_string |> ms_api_error_of_yojson
  in
  let ms_error_json =
    match ms_error_res with
    | Ok e -> e
    | Error _ ->
        {
          message = "[mlwt] Could not read MS error";
          code = "";
          error_type = "";
          link = "";
        }
  in
  match err with
  | `Bad_request -> Lwt_result.fail (`BadRequest ms_error_json)
  | `Unauthorized -> Lwt_result.fail (`Unauthorized ms_error_json)
  | `Forbidden -> Lwt_result.fail (`Forbidden ms_error_json)
  | `Not_found -> Lwt_result.fail (`NotFound ms_error_json)

let get_json conn endpoint_url =
  let url = make_ms_url conn endpoint_url in
  let headers = make_header ~key:(Meilisearch_client.key conn) in
  Lwt.catch
    (fun () ->
      let* resp, resp_body = Cohttp_lwt_unix.Client.get ~headers url in
      match Cohttp.Response.status resp with
      | `OK | `Created | `Accepted | `No_content | `Reset_content ->
          body_to_yojson resp_body
      | (`Bad_request | `Unauthorized | `Forbidden | `Not_found) as err ->
          build_err err resp_body
      | code ->
          Lwt_result.fail
            (`InternalError
               (Printf.sprintf "Not-documented http code from MS server: %d\n"
                  (Cohttp.Code.code_of_status code))))
    (fun exn -> Lwt_result.fail (`NotReachable (Printexc.to_string exn)))

let get_and_decode conn endpoint_url decoder =
  let* json_res = get_json conn endpoint_url in
  match json_res with
  | Ok j ->
      Lwt.return
      @@ (decoder j |> Result.map_error (fun e -> `SerializationError e))
  | Error e -> Lwt_result.fail e

let post_to_ms conn endpoint_url json_body =
  let url = make_ms_url conn endpoint_url in
  let body = make_body json_body in
  let headers = make_header ~key:(Meilisearch_client.key conn) in
  Lwt.catch
    (fun () ->
      let* resp, resp_body = Cohttp_lwt_unix.Client.post ~headers ~body url in
      match Cohttp.Response.status resp with
      | `OK | `Created | `Accepted | `No_content | `Reset_content ->
          let* body = Cohttp_lwt.Body.to_string resp_body in
          let res = Yojson.Safe.from_string body in
          Lwt_result.return res
      | (`Bad_request | `Unauthorized | `Forbidden | `Not_found) as err ->
          build_err err resp_body
      | code ->
          Lwt_result.fail
            (`InternalError
               (Printf.sprintf "Not-documented http code from MS server: %d\n"
                  (Cohttp.Code.code_of_status code))))
    (fun exn -> Lwt_result.fail (`NotReachable (Printexc.to_string exn)))

let put_to_ms conn endpoint_url json_body =
  let url = make_ms_url conn endpoint_url in
  let body = make_body json_body in
  let headers = make_header ~key:(Meilisearch_client.key conn) in
  Lwt.catch
    (fun () ->
      let* resp, resp_body = Cohttp_lwt_unix.Client.put ~headers ~body url in
      match Cohttp.Response.status resp with
      | `OK | `Created | `Accepted | `No_content | `Reset_content ->
          let* body = Cohttp_lwt.Body.to_string resp_body in
          let res = Yojson.Safe.from_string body in
          Lwt_result.return res
      | (`Bad_request | `Unauthorized | `Forbidden | `Not_found) as err ->
          build_err err resp_body
      | code ->
          Lwt_result.fail
            (`InternalError
               (Printf.sprintf "Not-documented http code from MS server: %d\n"
                  (Cohttp.Code.code_of_status code))))
    (fun exn -> Lwt_result.fail (`NotReachable (Printexc.to_string exn)))

let patch_to_ms conn endpoint_url json_body =
  let url = make_ms_url conn endpoint_url in
  let body = make_body json_body in
  let headers = make_header ~key:(Meilisearch_client.key conn) in
  Lwt.catch
    (fun () ->
      let* resp, resp_body = Cohttp_lwt_unix.Client.patch ~headers ~body url in
      match Cohttp.Response.status resp with
      | `OK | `Created | `Accepted | `No_content | `Reset_content ->
          let* body = Cohttp_lwt.Body.to_string resp_body in
          let res = Yojson.Safe.from_string body in
          Lwt_result.return res
      | (`Bad_request | `Unauthorized | `Forbidden | `Not_found) as err ->
          build_err err resp_body
      | code ->
          Lwt_result.fail
            (`InternalError
               (Printf.sprintf "Not-documented http code from MS server: %d\n"
                  (Cohttp.Code.code_of_status code))))
    (fun exn -> Lwt_result.fail (`NotReachable (Printexc.to_string exn)))

let delete_to_ms_task conn endpoint_url =
  let url = make_ms_url conn endpoint_url in
  let headers = make_header ~key:(Meilisearch_client.key conn) in
  let* resp, resp_body = Cohttp_lwt_unix.Client.delete ~headers url in
  Lwt.catch
    (fun () ->
      match Cohttp.Response.status resp with
      | `OK | `Created | `Accepted | `No_content | `Reset_content ->
          let* body = Cohttp_lwt.Body.to_string resp_body in
          let res = Yojson.Safe.from_string body in
          Lwt_result.return res
      | (`Bad_request | `Unauthorized | `Forbidden | `Not_found) as err ->
          build_err err resp_body
      | code ->
          Lwt_result.fail
            (`InternalError
               (Printf.sprintf "Not-documented http code from MS server: %d\n"
                  (Cohttp.Code.code_of_status code))))
    (fun exn -> Lwt_result.fail (`NotReachable (Printexc.to_string exn)))
