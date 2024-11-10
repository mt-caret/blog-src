open! Core

let generate_pragma slug =
  print_endline
    [%string
      {|
(rule
 (deps ../scripts/build.sh ../templates/post.html ../src/%{slug}.md git-revision)
 (targets %{slug}.html)
 (action
  (run ../scripts/build.sh ../src/%{slug}.md %{slug}.html git-revision)))|}]
;;

let () =
  let source_files =
    Sys_unix.ls_dir "../src"
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
