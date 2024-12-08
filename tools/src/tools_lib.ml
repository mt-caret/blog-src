open! Core
module Syndication = Syndication

let write_endline string ~filename =
  let open Shexp_process in
  echo ~where:Stdout ~n:() string |> outputs_to filename
;;

let evaluate_template input_file ~template =
  let open Shexp_process in
  let open Shexp_process.Let_syntax in
  with_temp_file ~prefix:"" ~suffix:".template" (fun template_file ->
    let%bind () = write_endline template ~filename:template_file in
    run "pandoc" [ input_file; "--template"; template_file ])
  |- read_all
;;

let get_metadata input_file =
  evaluate_template input_file ~template:"$meta-json$"
  |> Shexp_process.map ~f:Metadata.parse
;;

let get_body input_file = evaluate_template input_file ~template:"$body$"

let load_site_config site_config_path =
  let open Shexp_process in
  let open Shexp_process.Let_syntax in
  let%map site_config_json = stdin_from site_config_path read_all in
  [%of_yojson: Syndication.Site_config.t] (Yojson.Safe.from_string site_config_json)
;;

let generate_posts_for_syndication
  ~input_dir
  ~output_dir
  ({ base_url; _ } as site_config : Syndication.Site_config.t)
  =
  let module List' = List in
  let open Shexp_process in
  let open Shexp_process.Let_syntax in
  let%bind posts =
    readdir input_dir
    >>| List'.sort ~compare:String.compare
    >>| List'.filter_map ~f:(fun file ->
      String.chop_suffix ~suffix:".md" file
      |> Option.map ~f:(fun slug ->
        let path = Filename.concat input_dir file in
        let%map metadata = get_metadata path
        and content_html = get_body path in
        Syndication.Post.create metadata ~slug ~base_url ~content_html))
    >>= fork_all
  in
  let%bind () =
    Syndication.create_rss_feed site_config posts
    |> write_endline ~filename:(Filename.concat output_dir "rss.xml")
  in
  Syndication.create_atom_feed site_config posts
  |> write_endline ~filename:(Filename.concat output_dir "atom.xml")
;;

let syndication_feeds =
  Command.basic ~summary:"Generate syndication feeds"
  @@
  let%map_open.Command input_dir = anon ("INPUT_DIR" %: string)
  and output_dir = anon ("OUTPUT_DIR" %: string)
  and site_config =
    flag "site-config" (required string) ~doc:"Path to site config file"
  in
  fun () ->
    let open Shexp_process in
    let open Shexp_process.Let_syntax in
    load_site_config site_config
    >>= generate_posts_for_syndication ~input_dir ~output_dir
    |> eval
;;

let generate_pragma slug =
  let git_revision_variable = "%{read-lines:../git-revision}" in
  print_endline
    [%string
      {|
(rule
 (deps ../../scripts/build.sh (glob_files ../../templates/*.html) ../../src/%{slug}.md ../git-revision)
 (targets %{slug}.html)
 (action
  (run ../../scripts/build.sh ../../src/%{slug}.md %{slug}.html "%{git_revision_variable}")))|}]
;;

let print_dune_rules =
  Command.basic ~summary:"Print out dune rules"
  @@
  let%map_open.Command input_dir = anon ("INPUT_DIR" %: string) in
  fun () ->
    let source_files =
      Sys_unix.ls_dir input_dir
      |> List.sort ~compare:String.compare
      |> List.filter_map ~f:(fun file -> String.chop_suffix file ~suffix:".md")
    in
    List.iter source_files ~f:generate_pragma;
    let output_files = List.map source_files ~f:(fun file -> [%string "%{file}.html"]) in
    print_endline
      [%string
        {|
(alias
  (name default)
  (deps %{String.concat ~sep:" " output_files}))
  |}]
;;

let command =
  Command.group
    ~summary:"Tools for generating blog"
    [ "syndication-feeds", syndication_feeds; "print-dune-rules", print_dune_rules ]
;;
