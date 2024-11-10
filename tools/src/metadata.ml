open! Core
open Ppx_yojson_conv_lib.Yojson_conv

module Date = struct
  type t = Date.t [@@deriving sexp_of]

  let t_of_yojson json = string_of_yojson json |> Date.of_string
end

type t =
  { date : Date.t
  ; update_date : Date.t option [@default None]
  ; title : string
  ; category : string [@default "uncategorized"]
  ; tags : string list [@default []]
  ; uuid : string
  }
[@@deriving of_yojson, sexp_of] [@@yojson.allow_extra_fields]

let parse s =
  let json = Yojson.Safe.from_string s in
  match [%of_yojson: t] json with
  | x -> x
  | exception exn ->
    raise_s
      [%message "Unexpected error while parsing metadata" (exn : exn) (json : Json.t)]
;;
