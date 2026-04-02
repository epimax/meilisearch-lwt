type t = { url : string; key : string }

let create ~url ~key = { url; key }
let url conn = conn.url
let key conn = conn.key
