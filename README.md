# Meilisearch-lwt

**An asynchronous OCaml client library for Meilisearch built on Lwt.**

This library was initially created with search and query workloads in mind.

The Meilisearch HTTP API coverage is very partial, many endpoints are missing.

The library treats documents and search results as Yojson.Safe.t, serialization and deserialization must be done on your side.

It was designed to be used alongside Ocsigen projects, therefore all APIs are Lwt based and no blocking API is provided.

## Current scope

The current version provides APIs for:
 * indexes
 * documents
 * search
 * asynchronous tasks
 * basic settings (on indexes)

*Note: Enterprise features are not supported.*

Meilisearch documents are represented as `Yojson.Safe.t`.
The library doesn't enforce a document schema.
Users can provide their own typed models and serialization functions.

JSON serialization uses `Yojson` and its `ppx_deriving_yojson` PPX.
HTTP communication is handled through `Cohttp-lwt-unix`.

The intended deployment model is to keep your Meilisearch instance private and access it through an application server (ergo Ocsigen, Dream...) or reverse proxy.

## Requirements

Currently tested with
* OCaml >= 5.2
* Dune >= 3.0
* Lwt
* Meilisearch instance >= 1.45

## Installation

Currently not released on opam, you'll have to install this manually in your switch.

Clone this repository:
```
git clone https://github.com/epimax/meilisearch-lwt.git
cd meilisearch-lwt/
```

Create a switch:
```
opam switch create . 5.2.0
eval $(opam env)
```

Install dependencies:
```
opam install . --deps-only
```

Build:
```
dune build
```

## Tests

Unit tests do not require external services:
```
dune runtest
```

Integration tests require a running Meilisearch instance and an API key with
enough permissions to create indexes, write documents, search, and read tasks:
```
MEILISEARCH_URL=http://localhost:7700 \
MEILISEARCH_API_KEY=<api-key> \
dune exec tests/integration_tests.exe
```

### Using as an opam pin

You can also use the repository directly:
```
opam pin add meilisearch-lwt git+https://github.com/epimax/meilisearch-lwt.git
```

## Examples

First you need to create a client, provide a key with the correct permissions.
The connection step performs a health check against Meilisearch [/health].
```
open Lwt.Syntax

let connect () =
  let* conn = Meilisearch_lwt.connect
    ~url:"http://localhost:7700"
    ~key:"your_api_key"
  in
  match conn with
    | Ok c -> Lwt.return c
    | Error e -> Lwt.fail_with (Meilisearch_lwt.error_to_string e)
```

Another example here for Index creation, since it's one of the many asynchronous call to Meilisearch, it'll show you how to claim the task id from the server and wait for the task completion using the library.
```
open Lwt.Syntax

let create_index conn ~index_uid ~pk =
  let* index_create_task_r = Meilisearch_lwt.Index.create_index
    conn
    ~index_uid
    ~pk
  in
  match index_create_task_r with
    | Ok t -> Lwt.return t
    | Error e -> Lwt.fail_with (Meilisearch_lwt.Index.error_to_string e)

let create_idx_wait_tsk conn () =
  let* idx_creation_task_id = create_index
    conn
    ~index_uid:"my_test_index"
    ~pk:"id"
  in
  let* task_c = Meilisearch_lwt.Task.wait_task
    conn
    ~max_attempts:50
    ~delay:0.2
    idx_creation_task_id
  in match task_c with
    | Ok t -> Lwt.return (Printf.printf "Index created, task: %d has status: %s\n"
        t.uid
      (Meilisearch_lwt.Task.task_status_to_string t.status))
    | Error e -> Lwt.return (Printf.printf "Task: %d hasn't completed: %s\n"
        idx_creation_task_id
        (Meilisearch_lwt.Task.error_to_string e))
```

Before adding documents, you should configure your index settings, see examples/. Once done, you can do something like this:
```
open Lwt.Syntax

type document_example = {
  id : int;
  content : string;
  title : string
} [@@deriving yojson]

let insert_document_example conn index_uid =
  let doc = {
    id = 0;
    content = "Need some content to be indexed.";
    title = "Example document"
  }
  in
  let* add_doc_task_r = Meilisearch_lwt.Document.add_document
    conn
    ~index_uid
    document_example_to_yojson
    doc
  in
  match add_doc_task_r with
    | Ok u -> Lwt.return u
    | Error e -> Lwt.fail_with (Meilisearch_lwt.Document.error_to_string e)

```

And finally, to perform a search with a single term, do the following, complex searches requests are detailed in examples/.
```
open Lwt.Syntax

module Q = Meilisearch_lwt.Search.Query

let search_by_term conn index_uid term =
  let q = Q.init ()
    |> Q.add_query term
    |> Q.add_attributes_to_retrieve ["title"; "content"]
  in
  let* search_r = Meilisearch_lwt.Search.search_post conn ~index_uid q
  in
  match search_r with
    | Ok r -> Printf.printf "Search results: [%s]\n" (Yojson.Safe.pretty_to_string r); Lwt.return_unit
    | Error e -> (* Treat error properly *)
      Printf.printf "Error with search request: %s\n" (Meilisearch_lwt.Search.error_to_string e); Lwt.return_unit
```

Looking at examples/ and tests/ will give you more complete example for the Document, Search and Settings modules. Also check the documentation !
If you want to run the examples, runs the index example first, it'll create the index needed to run the document example.
Subsequent launches of the index example are bound to fail, we do not remove the index at any point.
Additionally, you need to set both environment variable: ```MEILISEARCH_URL``` & ```MEILISEARCH_API_KEY``` for the hostname and the master key.

## Errors

All asynchronous functions return Result values wrapped in Lwt promises.

Errors are represented as polymorphic variants.
Each module exposes an error_to_string helper.
You can pattern match on errors when you need custom handling
```
match result with
  | Error (`Timeout msg ) -> (* handle ongoing task *)
  | Error e -> Printf.printf "Failed: %s\n" (Meilisearch_lwt.Task.error_to_string e)
```

For which you want to read the task fields, with the helpers provided in the Task module, while the error_to_string will just yield you the ```details``` field from Meilisearch payload.

## Status

This project is currently in early development.
The API is stabilizing and may change before the first stable release.
It has been tested against local Meilisearch instances.
