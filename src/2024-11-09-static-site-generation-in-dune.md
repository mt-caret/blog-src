---
title: Static site generation in dune
date: 2024-11-09
---

It's been a while. People have suggested that I blog again, so here I am. Mostly
it's been a lack of time, but getting my static site generator working again was
too painful for me to muster the energy to write anything. Let's fix that first.

[Dune], the build system often used for OCaml projects, is pretty general,
and you can use it as a Makefile-on-steroids.

Here's a simple dune rule for building a markdown file into an html file:

```
(rule
 (deps build.sh 2024-11-09-static-site-generation-in-dune.md)
 (targets 2024-11-09-static-site-generation-in-dune.html)
 (action
  (run build.sh 2024-11-09-static-site-generation-in-dune.md 2024-11-09-static-site-generation-in-dune.html)))
```

Where `build.sh` can do whatever you want to turn the markdown into html. I use
pandoc for this site. There's an immediate problem with this approach. We need
to write one rule for every markdown file! What we want is something like
[recursive Makefiles](https://accu.org/journals/overload/14/71/miller_2004/)
to generate rules for each markdown file, but for dune.

Fortunately, the dune docs have a tutorial on
["rule generation"](https://dune.readthedocs.io/en/stable/howto/rule-generation.html)
that walks us through doing just this.

The main dune file in our directory would look like this:

```
(include dune.inc)

(rule
 (deps
  (source_tree .))
 (action
  (with-stdout-to
   dune.inc.gen
   (run ../gen/gen.exe))))

(rule
 (alias default)
 (action
  (diff dune.inc dune.inc.gen)))
```

The idea here is that we'll have a program-generated `dune.inc` file which this
`dune` file will include. Whenever there is a change in the source directory
containing markdown files, `../gen/gen.exe` will be invoked to re-generate
the `dune.inc` file, which will then result in a diff between the old and new
`dune.inc` files due to the `(diff ...)` rule.

`dune promote` will update the generated `dune.inc` file to the new version,
and `dune build` will rebuild all the markdown files. Using
`dune build -w @default --auto-promote` will automate the promotion and watch
for changes.

The source for `gen.exe` looks like this:

```ocaml
open! Core

let generate_pragma slug =
  print_endline
    [%string
      {|
(rule
 (deps build.sh %{slug}.md)
 (targets %{slug}.html)
 (action
  (run build.sh %{slug}.md %{slug}.html)))|}]
;;

let () =
  let source_files =
    Sys_unix.ls_dir "."
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
```