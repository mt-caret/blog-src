open! Core
open! Import

type t =
  { path : Filename.t
  ; slug : string
  }
[@@deriving fields ~getters]

val readdir : input_dir:Filename.t -> t list Shexp_process.t
