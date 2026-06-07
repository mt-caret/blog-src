open! Core

type t =
  | English
  | Japanese
[@@deriving enumerate, sexp_of, equal]

let default = English

let code = function
  | English -> "en"
  | Japanese -> "ja"
;;

let label = function
  | English -> "English"
  | Japanese -> "日本語"
;;

let of_slug slug =
  List.filter all ~f:(Fn.non (equal default))
  |> List.find_map ~f:(fun t ->
    String.chop_suffix slug ~suffix:[%string ".%{code t}"]
    |> Option.map ~f:(fun base -> t, base))
  |> Option.value ~default:(default, slug)
;;
