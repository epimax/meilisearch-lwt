(lang dune 3.20)

(name meilisearch-lwt)

(generate_opam_files true)

(source
 (github epimax/meilisearch-lwt))

(authors "epimax <maxime@epimax.fr>")

(maintainers "epimax <maxime@epimax.fr>")

(license MIT)

(version 0.1.0)

(package
 (name meilisearch-lwt)
 (synopsis "Asynchronous OCaml client for Meilisearch using Lwt")
 (description "A non-blocking OCaml client library for Meilisearch. Provides Lwt-based APIs for indexes, documents, search and tasks.")
 (depends
   (ocaml (>= 5.2.0))
   (dune (>= 3.20))
   (lwt (>= 5.7.0))
   (cohttp-lwt-unix (>= 5.3.0))
   (yojson (>= 3.0.0))
   (ppx_deriving_yojson (>= 3.9.1))
   (alcotest-lwt :with-test)
   (odoc :with-doc)))
