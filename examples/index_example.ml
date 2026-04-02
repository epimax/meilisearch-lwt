open Lwt.Syntax

let create_index conn ~index_uid ~pk =
  let* index_create_task_r =
    Meilisearch_lwt.Index.create_index conn ~index_uid ~pk
  in
  let* index_create_task_uid =
    Example_common.or_fail "create_index" Meilisearch_lwt.Index.error_to_string
      index_create_task_r
  in
  let* task_c =
    Meilisearch_lwt.Task.wait_task conn ~max_attempts:50 ~delay:0.2
      index_create_task_uid
  in
  match task_c with
  | Ok t ->
      Lwt.return
        (Printf.printf "Index: %s created: %s\n" index_uid
           (Meilisearch_lwt.Task.task_status_to_string t.status))
  | Error e ->
      Lwt.return
        (Printf.printf "Index creation failed, task %d has error: %s\n"
           index_create_task_uid
           (Meilisearch_lwt.Task.error_to_string e))

let recommended_settings conn index =
  let open Meilisearch_lwt.Settings in
  let settings =
    Settings.init ()
    |> Settings.set_ranking_rules [ "words"; "typo"; "proximity" ]
    |> Settings.set_filterable_attributes [ "id"; "content" ]
    |> Settings.set_searchable_attributes [ "id"; "content" ]
  in
  let* update_settings_task_r = update_all_settings conn index settings in
  let* update_settings_task_uid =
    Example_common.or_fail
      (Printf.sprintf "update settings for index %s" index.uid)
      error_to_string update_settings_task_r
  in
  let* task_c =
    Meilisearch_lwt.Task.wait_task conn ~max_attempts:50 ~delay:0.2
      update_settings_task_uid
  in
  match task_c with
  | Ok t ->
      Lwt.return
        (Printf.printf "Settings on index: %s were updated, task took %s !\n"
           index.uid
           (Option.value t.duration ~default:"Unknown Amount of time"))
  | Error e ->
      Lwt.return
        (Printf.printf "Could not update index settings: %s\n"
           (Meilisearch_lwt.Task.error_to_string e))

let index_setup conn =
  let index_uid = "my_first_index" in
  let* () = create_index conn ~index_uid ~pk:"id" in
  let* index_r = Meilisearch_lwt.Index.get_index conn ~index_uid in
  let* index =
    Example_common.or_fail "get_index" Meilisearch_lwt.Index.error_to_string
      index_r
  in
  let* () = recommended_settings conn index in
  Lwt.return_unit

let () =
  Lwt_main.run
    (let* conn = Example_common.connect_or_fail () in
     let* () = index_setup conn in
     Lwt.return_unit)
