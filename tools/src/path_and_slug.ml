open! Core
open! Import

type t =
  { path : Filename.t
  ; slug : string
  }

let readdir ~input_dir =
  let open Shexp_process.Infix in
  Shexp_process.readdir input_dir
  >>| List.filter_map ~f:(fun filename ->
    String.chop_suffix ~suffix:".md" filename
    |> Option.map ~f:(fun slug -> { path = Filename.concat input_dir filename; slug }))
;;
