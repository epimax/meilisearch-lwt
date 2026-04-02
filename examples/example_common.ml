open Lwt.Syntax

let getenv_required name =
  match Sys.getenv_opt name with
  | Some value -> value
  | _ -> failwith (Printf.sprintf "Missing %s in env." name)

let or_fail where error_to_string = function
  | Ok value -> Lwt.return value
  | Error error ->
      Lwt.fail_with (Printf.sprintf "%s: %s" where (error_to_string error))

let connect_or_fail () =
  let url = getenv_required "MEILISEARCH_URL" in
  let key = getenv_required "MEILISEARCH_API_KEY" in
  let* conn_r = Meilisearch_lwt.connect ~url ~key in
  or_fail "connect" Meilisearch_lwt.error_to_string conn_r
