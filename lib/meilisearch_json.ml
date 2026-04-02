type t = (string * Yojson.Safe.t) list

let init () = []
let add key value q = (key, value) :: q
let add_param_string key value q = add key (`String value) q

let add_param_string_list key values q =
  add key (`List (List.map (fun v -> `String v) values)) q

let add_param_int key value q = add key (`Int value) q
let add_param_bool key value q = add key (`Bool value) q
let add_param_float key value q = add key (`Float value) q

let add_param_float_list key values q =
  add key (`List (List.map (fun v -> `Float v) values)) q

let add_param_obj f key values q = add key (f values) q
let to_yojson q = `Assoc (List.rev q)
