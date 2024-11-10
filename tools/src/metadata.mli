open! Core

type t =
  { date : Date.t
  ; update_date : Date.t option
  ; title : string
  ; category : string
  ; tags : string list
  ; uuid : string
  }
[@@deriving of_yojson, sexp_of]

val parse : string -> t
