(** Task management. Meilisearch works in batches, and since these are queued
    you might not always get a success/failure response from the server
    immediately: the task API will let you know. *)

(** {1 Shared types and functions} *)

type task_status =
  | Enqueued
  | Processing
  | Succeeded
  | Failed
  | Canceled
      (** Variant that reflects task possible status for you to match
          accordingly *)

type task = {
  batchUid : int option; [@default None]
  uid : int;
  indexUid : string;
  status : task_status;
  tasktype : string; [@key "type"]
  canceledBy : string option;
  details : Yojson.Safe.t;
  error : Yojson.Safe.t option;
  duration : string option;
  enqueuedAt : string;
  startedAt : string option;
  finishedAt : string option;
}
[@@deriving yojson]
(** The task record. Polymorphic fields are left as Yojson.Safe.t (option);
    other fields, if present, should be exploitable. *)

type task_error =
  [ Meilisearch_error.t
  | `NoSuchTask of string
  | `TaskFailed of string
  | `TaskCanceled of string
  | `Timeout of task ]
(** Errors that can occur in this module: task failures, timeouts while waiting,
    and also network/system errors. *)

val get_task :
  Meilisearch_client.t -> task_uid:int -> (task, task_error) result Lwt.t
(** [get_task client ~task_uid] returns the instantaneous state of the task. *)

val task_status_to_string : task_status -> string
(** Helper provided for debugging. *)

val error_to_string : task_error -> string
(** [error_to_string error] converts the polymorphic error variant of this
    module into a human-readable string. *)

val wait_task :
  Meilisearch_client.t ->
  ?max_attempts:int ->
  delay:float ->
  int ->
  (task, task_error) result Lwt.t
(** [wait_task client ?max_attempts ~delay task_id] returns a promise that
    resolves when the task is completed, canceled, or has timed out according to
    the max_attempts provided or the instance behavior. Delay is expressed in
    seconds. *)

val check_task :
  Meilisearch_client.t -> task_uid:int -> (task_status, task_error) result Lwt.t
(** [check_task client ~task_uid] returns the instantaneous status of the task.
    If you want the full task details, you need to call {!get_task}. *)
