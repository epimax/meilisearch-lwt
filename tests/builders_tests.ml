module To_test = struct
  module Q = Meilisearch_lwt.Search.Query

  let build_search_query () =
    let q =
      Q.init () |> Q.add_query "term"
      |> Q.add_attributes_to_retrieve [ "id"; "content" ]
      |> Q.add_show_matches_position true
    in
    let yojson_q = Q.to_yojson q in
    Yojson.Safe.pretty_to_string yojson_q

  let build_search_query_2 () =
    let q =
      Q.init () |> Q.add_query "term"
      |> Q.add_crop_length ~value:15
      |> Q.add_ranking_score_threshold 0.5
    in
    let yojson_q = Q.to_yojson q in
    Yojson.Safe.pretty_to_string yojson_q

  module S = Meilisearch_lwt.Settings.Settings

  let build_setting_query () =
    let s =
      S.init ()
      |> S.set_ranking_rules [ "words"; "typo"; "proximity" ]
      |> S.set_filterable_attributes [ "id"; "content" ]
      |> S.set_searchable_attributes [ "id"; "content" ]
    in
    let yojson_s = S.to_yojson s in
    Yojson.Safe.pretty_to_string yojson_s

  let build_setting_query_2 () =
    let s = S.init () |> S.set_filterable_attributes [] in
    let yojson_s = S.to_yojson s in
    Yojson.Safe.pretty_to_string yojson_s
end

let test_search_query_out_json () =
  let expected =
    {|{
  "q": "term",
  "attributesToRetrieve": [ "id", "content" ],
  "showMatchesPosition": true
}|}
  in
  let actual = To_test.build_search_query () in
  Alcotest.(check string) "Search" expected actual

let test_setting_query_out_json () =
  let expected =
    {|{
  "rankingRules": [ "words", "typo", "proximity" ],
  "filterableAttributes": [ "id", "content" ],
  "searchableAttributes": [ "id", "content" ]
}|}
  in
  let actual = To_test.build_setting_query () in
  Alcotest.(check string) "Settings" expected actual

let test_search_query_out_json_2 () =
  let expected =
    {|{ "q": "term", "cropLength": 15, "rankingScoreThreshold": 0.5 }|}
  in
  let actual = To_test.build_search_query_2 () in
  Alcotest.(check string) "Search (2)" expected actual

let test_setting_query_out_json_2 () =
  let expected = {|{ "filterableAttributes": [] }|} in
  let actual = To_test.build_setting_query_2 () in
  Alcotest.(check string) "Settings (2)" expected actual

let () =
  let open Alcotest in
  run "Querries & Settings builder tests suite"
    [
      ( "Builder JSON validation",
        [
          test_case "Build search query (str, str list)."       `Quick test_search_query_out_json;
          test_case "Build index settings (add settings)."      `Quick test_setting_query_out_json;
          test_case "Build search query (ints, floats)."        `Quick test_search_query_out_json_2;
          test_case "Build index settings (remove settings)."   `Quick test_setting_query_out_json_2;
        ] );
    ]
