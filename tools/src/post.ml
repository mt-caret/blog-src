open! Core
open! Import

type t =
  { metadata : Metadata.t
  ; content_html : string
  }
[@@deriving sexp_of, fields ~getters]

let load filename ~slug =
  let%map.Shexp_process metadata = Metadata.load filename ~slug
  and content_html = Markdown.get_content_html filename in
  { metadata; content_html }
;;

let load_all ~input_dir =
  let open Shexp_process.Infix in
  Path_and_slug.readdir ~input_dir
  >>| List.map ~f:(fun ({ path; slug } : Path_and_slug.t) -> load path ~slug)
  >>= Shexp_process.fork_all
  >>| List.sort
        ~compare:(Comparable.lift [%compare: Date.t] ~f:(Metadata.date << metadata))
;;
