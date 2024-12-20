open! Core
open! Import

let evaluate_template input_file ~template =
  let open Shexp_process in
  let open Shexp_process.Let_syntax in
  with_temp_file ~prefix:"" ~suffix:".template" (fun template_file ->
    let%bind () = write_endline template ~filename:template_file in
    run "pandoc" [ input_file; "--template"; template_file ])
  |- read_all
;;

let get_metadata_json input_file = evaluate_template input_file ~template:"$meta-json$"
let get_content_html input_file = evaluate_template input_file ~template:"$body$"
