open! Core

module From_frontmatter : sig
  type t =
    { date : Date.t
    ; update_date : Date.t option
    ; title : string
    ; category : string
    ; tags : string list
    ; uuid : string
    }
  [@@deriving sexp_of]

  val load : string -> t Shexp_process.t
end

type t =
  { date : Date.t
  ; update_date : Date.t option
  ; title : string
  ; category : string
  ; tags : string list
  ; uuid : string
  ; slug : string
  }
[@@deriving sexp_of, fields ~getters]

val create : From_frontmatter.t -> slug:string -> t
val load : Filename.t -> slug:string -> t Shexp_process.t
val load_all : input_dir:Filename.t -> t list Shexp_process.t
