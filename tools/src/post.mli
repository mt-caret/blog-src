open! Core
open! Import

type t =
  { metadata : Metadata.t
  ; content_html : string
  }
[@@deriving sexp_of, fields ~getters]

val load : string -> slug:string -> t Shexp_process.t
val load_all : input_dir:string -> t list Shexp_process.t
