open! Core
open! Import
module Syndication = Syndication

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
  let open Shexp_process.Let_syntax in
  let%bind posts =
    Post.load_all ~input_dir >>| List.map ~f:(Syndication.Post.create ~base_url)
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
  let%map_open.Command input_dir = anon ("INPUT_DIR" %: Filename_unix.arg_type)
  and output_dir = anon ("OUTPUT_DIR" %: Filename_unix.arg_type)
  and site_config =
    flag "site-config" (required Filename_unix.arg_type) ~doc:"Path to site config file"
  in
  fun () ->
    let open Shexp_process in
    let open Shexp_process.Let_syntax in
    load_site_config site_config
    >>= generate_posts_for_syndication ~input_dir ~output_dir
    |> eval
;;

let build_post =
  Command.basic ~summary:"Build a post"
  @@
  let%map_open.Command input_file = anon ("INPUT_FILE" %: Filename_unix.arg_type)
  and output_file = anon ("OUTPUT_FILE" %: Filename_unix.arg_type)
  and git_revision = flag "git-revision" (required string) ~doc:"Git revision"
  and template_file =
    flag "template" (required Filename_unix.arg_type) ~doc:"Path to template file"
  in
  fun () ->
    let open Shexp_process in
    eval
    @@ run
         "pandoc"
         [ input_file
         ; "--output"
         ; output_file
         ; "--template"
         ; template_file
         ; "--variable"
         ; [%string "rev:%{git_revision}"]
         ; "--to=html5"
         ]
;;

(* TODO: It's confusing that there's Metadata.t and Post_metadata.t; fix this. *)
module Post_metadata = struct
  open Ppx_yojson_conv_lib.Yojson_conv

  type t =
    { date : Yojson_date.t
    ; title : string
    ; href : string
    }
  [@@deriving yojson_of]

  let of_metadata (metadata : Metadata.t) ~dir =
    { date = metadata.date
    ; title = metadata.title
    ; href = Filename.concat dir (metadata.slug ^ ".html")
    }
  ;;
end

let build_index =
  Command.basic ~summary:"Build index.html"
  @@
  let%map_open.Command input_dir = anon ("INPUT_DIR" %: Filename_unix.arg_type)
  and git_revision = flag "git-revision" (required string) ~doc:"Git revision"
  and template_file =
    flag "template" (required Filename_unix.arg_type) ~doc:"Path to template file"
  in
  fun () ->
    let module List' = List in
    let open Shexp_process in
    let open Shexp_process.Infix in
    eval
    @@
    let%bind.Shexp_process posts =
      Metadata.load_all ~input_dir
      >>| (* We want the newest posts first *)
      List'.rev
      >>| List'.map ~f:(Post_metadata.of_metadata ~dir:"./posts/")
      >>| Ppx_yojson_conv_lib.Yojson_conv.([%yojson_of: Post_metadata.t list])
      >>| Yojson.Safe.to_string
    in
    echo [%string {|---
title: blog
posts: %{posts}
---|}]
    |- run
         "pandoc"
         [ "--template"
         ; template_file
         ; "--variable"
         ; [%string "rev:%{git_revision}"]
         ; "--to=html5"
         ]
;;

let post_generation_rule slug ~self_path ~template_file ~git_revision_file =
  let git_revision_variable = "%{read-lines:" ^ git_revision_file ^ "}" in
  let template_dir = Filename.dirname template_file in
  [%string
    {|(rule
 (deps %{self_path} (glob_files %{template_dir}/*.html) ../../src/%{slug}.md %{git_revision_file})
 (targets %{slug}.html)
 (action
  (run
    %{self_path}
    build-post
    ../../src/%{slug}.md
    %{slug}.html
    -git-revision "%{git_revision_variable}"
    -template %{template_file}
    )))|}]
;;

let print_dune_rules =
  Command.basic ~summary:"Print out dune rules"
  @@
  let%map_open.Command input_dir = anon ("INPUT_DIR" %: Filename_unix.arg_type)
  and template_file =
    flag "template" (required Filename_unix.arg_type) ~doc:"Path to template file"
  and git_revision_file =
    flag
      "git-revision-file"
      (required Filename_unix.arg_type)
      ~doc:"Path to git revision file"
  in
  fun () ->
    let module List' = List in
    let open Shexp_process in
    let open Shexp_process.Let_syntax in
    eval
    @@
    let self_path =
      (* [Command.Param.args] exists, but the directory seems to be stripped
         there, so we get argv directly. *)
      (Sys.get_argv ()).(0)
    in
    let%bind slugs =
      Path_and_slug.readdir ~input_dir >>| List'.map ~f:Path_and_slug.slug
    in
    let post_generation_rules =
      List'.map
        slugs
        ~f:(post_generation_rule ~self_path ~template_file ~git_revision_file)
      |> String.concat ~sep:"\n"
    in
    let output_files = List'.map slugs ~f:(fun file -> [%string "%{file}.html"]) in
    echo
      [%string
        {|; post generation rules
%{post_generation_rules}

; aggregation alias
(alias
  (name default)
  (deps %{String.concat ~sep:" " output_files}))
  |}]
;;

let command =
  Command.group
    ~summary:"Tools for generating blog"
    [ "syndication-feeds", syndication_feeds
    ; "print-dune-rules", print_dune_rules
    ; "build-post", build_post
    ; "build-index", build_index
    ]
;;
