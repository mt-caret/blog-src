open! Core

module From_frontmatter = struct
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

  let of_json_str s =
    let json = Yojson.Safe.from_string s in
    match [%of_yojson: t] json with
    | x -> x
    | exception exn ->
      raise_s
        [%message "Unexpected error while parsing metadata" (exn : exn) (json : Json.t)]
  ;;

  let load filename =
    Markdown.get_metadata_json filename |> Shexp_process.map ~f:of_json_str
  ;;
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

let create ({ date; update_date; title; category; tags; uuid } : From_frontmatter.t) ~slug
  =
  { date; update_date; title; category; tags; uuid; slug }
;;

let load filename ~slug =
  From_frontmatter.load filename |> Shexp_process.map ~f:(create ~slug)
;;

let load_all ~input_dir =
  let open Shexp_process.Infix in
  Path_and_slug.readdir ~input_dir
  >>| List.map ~f:(fun ({ path; slug } : Path_and_slug.t) -> load path ~slug)
  >>= Shexp_process.fork_all
  >>| List.sort ~compare:(Comparable.lift [%compare: Date.t] ~f:date)
;;
