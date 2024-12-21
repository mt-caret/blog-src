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
  let%map_open.Command input_dir = Param.input_dir
  and output_dir = Param.output_dir
  and site_config =
    flag
      "site-config"
      (required Filename_unix.arg_type)
      ~doc:"PATH Path to site config file"
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
  let%map_open.Command input_file = Param.input_file
  and output_file = Param.output_file
  and git_revision = Param.git_revision
  and template_file = Param.template_file in
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
    ; root_dir : string
    }
  [@@deriving yojson_of]

  let of_metadata (metadata : Metadata.t) ~root_dir =
    { date = metadata.date
    ; title = metadata.title
    ; href = Filename.concat root_dir (Filename.concat "posts/" (metadata.slug ^ ".html"))
    ; root_dir
    }
  ;;
end

module Build_index_for = struct
  type t =
    | All
    | Category of string
    | Tag of string

  let param =
    let%map_open.Command category =
      flag "category" (optional string) ~doc:"Generate index for category"
    and tag = flag "tag" (optional string) ~doc:"Generate index for tag" in
    match category, tag with
    | Some category, Some tag ->
      raise_s [%message "Cannot specify both category and tag" category tag]
    | Some category, None -> Category category
    | None, Some tag -> Tag tag
    | None, None -> All
  ;;

  let filter t (metadata : Metadata.t) =
    match t with
    | All -> true
    | Category category -> String.equal metadata.category category
    | Tag tag -> List.mem metadata.tags tag ~equal:String.equal
  ;;

  let title t =
    match t with
    | All -> "blog"
    | Category category -> [%string "'category: %{category}'"]
    | Tag tag -> [%string "'tag: %{tag}'"]
  ;;

  let index_generation_rule t ~self_path ~input_dir ~template_file ~git_revision_file =
    let git_revision_variable = "%{read-lines:" ^ git_revision_file ^ "}" in
    let template_dir = Filename.dirname template_file in
    match t with
    | All -> failwith "not supported"
    | Category category ->
      (* TODO: reduce duplication between this and tag branch *)
      [%string
        {|
(rule
 (deps %{self_path} (source_tree %{input_dir}) (glob_files %{template_dir}/*.html) %{git_revision_file})
 (action
  (with-stdout-to
   %{category}.html
   (run
    %{self_path}
    build-index
    %{input_dir}
    -category %{category}
    -git-revision "%{git_revision_variable}"
    -template %{template_file}
    -root-dir ..
    ))))|}]
    | Tag tag ->
      [%string
        {|
(rule
 (deps %{self_path} (source_tree %{input_dir}) (glob_files %{template_dir}/*.html) %{git_revision_file})
 (action
  (with-stdout-to
   %{tag}.html
   (run
    %{self_path}
    build-index
    %{input_dir}
    -tag %{tag}
    -git-revision "%{git_revision_variable}"
    -template %{template_file}
    -root-dir ..
    ))))|}]
  ;;
end

let build_index =
  Command.basic ~summary:"Build index.html"
  @@
  let%map_open.Command input_dir = Param.input_dir
  and git_revision = Param.git_revision
  and template_file = Param.template_file
  and build_index_for = Build_index_for.param
  and root_dir =
    flag
      "root-dir"
      (optional_with_default "." string)
      ~doc:"DIR root dir relative to output dir"
  in
  fun () ->
    let module List' = List in
    let open Shexp_process in
    let open Shexp_process.Infix in
    eval
    @@
    let%bind.Shexp_process post_metadata =
      Metadata.load_all ~input_dir
      >>| (* We want the newest posts first *)
      List'.rev
      >>| List'.filter ~f:(Build_index_for.filter build_index_for)
    in
    let posts =
      List'.map post_metadata ~f:(Post_metadata.of_metadata ~root_dir)
      |> Ppx_yojson_conv_lib.Yojson_conv.([%yojson_of: Post_metadata.t list])
      |> Yojson.Safe.to_string
    in
    let title = Build_index_for.title build_index_for in
    (* TODO: pass git-revision as yaml frontmatter? *)
    echo
      [%string
        {|---
title: %{title}
posts: %{posts}
root_dir: %{root_dir}
show_index_link: %{not (String.equal root_dir ".")#Bool}
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
  let%map_open.Command input_dir = Param.input_dir
  and template_file = Param.template_file
  and git_revision_file = Param.git_revision_file
  and kind =
    flag
      "kind"
      (optional_with_default
         `Index
         (Arg_type.enumerated
            (module struct
              type t =
                [ `Index
                | `Category
                | `Tag
                ]
              [@@deriving enumerate, sexp]

              let to_string = String.lowercase << Sexp.to_string << sexp_of_t
            end)))
      ~doc:"Kind of rule to print"
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
    match kind with
    | `Index ->
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
    | `Category ->
      let%bind metadata = Metadata.load_all ~input_dir in
      let all_categories =
        "uncategorized" :: List'.map metadata ~f:Metadata.category
        |> List'.dedup_and_sort ~compare:String.compare
      in
      let index_generation_rules =
        List'.map all_categories ~f:(fun category ->
          Build_index_for.index_generation_rule
            ~self_path
            ~input_dir
            ~template_file
            ~git_revision_file
            (Category category))
        |> String.concat ~sep:"\n"
      in
      let output_files =
        List'.map all_categories ~f:(fun category -> [%string "%{category}.html"])
      in
      echo
        [%string
          {|; category index generation rules
%{index_generation_rules}

; aggregation alias
(alias
  (name default)
  (deps %{String.concat ~sep:" " output_files}))
  |}]
    | `Tag ->
      let%bind metadata = Metadata.load_all ~input_dir in
      let all_tags =
        List'.concat_map metadata ~f:Metadata.tags
        |> List'.dedup_and_sort ~compare:String.compare
      in
      let index_generation_rules =
        List'.map all_tags ~f:(fun tag ->
          Build_index_for.index_generation_rule
            ~self_path
            ~input_dir
            ~template_file
            ~git_revision_file
            (Tag tag))
        |> String.concat ~sep:"\n"
      in
      let output_files = List'.map all_tags ~f:(fun tag -> [%string "%{tag}.html"]) in
      echo
        [%string
          {|; tag index generation rules
%{index_generation_rules}

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
