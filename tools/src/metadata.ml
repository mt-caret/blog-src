open! Core
open Ppx_yojson_conv_lib.Yojson_conv

type t =
  { date : Yojson_date.t
  ; update_date : Yojson_date.t option [@default None]
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
