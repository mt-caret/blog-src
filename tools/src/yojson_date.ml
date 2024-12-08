open Core
open Ppx_yojson_conv_lib.Yojson_conv

type t = Date.t [@@deriving sexp]

let t_of_yojson json = string_of_yojson json |> Date.of_string
let yojson_of_t t = Date.to_string t |> yojson_of_string
