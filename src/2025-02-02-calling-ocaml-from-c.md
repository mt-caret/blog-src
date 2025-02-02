---
title: Calling OCaml from C
date: 2025-02-02
category: tech
tags:
- dune
- OCaml
uuid: 6bf20f9a-1635-4cf0-98f2-80361e16eb61
---

These are some notes on putting together a `dune` file for creating a C
executable which calls OCaml code.

<!-- TODO: Add link to repository -->

The OCaml manual describes how to call OCaml code from C under the section
"Advanced example with callbacks" in the chapter "Interfacing C with OCaml",
using the following invocations to `ocamlopt`:

```bash
$ ocamlopt -output-obj -o modcaml.o mod.ml
$ ocamlopt -c modwrap.c
$ cp `ocamlopt -where`/libasmrun.a mod.a && chmod +w mod.a
$ ar r mod.a modcaml.o modwrap.o
$ cc -o prog -I `ocamlopt -where` main.c mod.a -lm
```

Reading [the section in the OCaml manual about `ocamlopt` command line options
carefully](https://ocaml.org/manual/5.3/native.html), it looks like we can use
`-output-complete-obj` to simplify above commands:

```bash
$ ocamlopt -output-complete-obj -o modcaml.o mod.ml
$ ocamlopt -c modwrap.c
$ cc -o prog_native2 -I `ocamlopt -where` main.c modcaml.o modwrap.o -lm
```

## Translating to dune

We first want to recreate the `modcaml.o` file. Grepping in the dune codebase
for `-output-complete-obj`, we find [this code which matches on
`Executables.Link_mode.t`](https://github.com/ocaml/dune/blob/bfe07c69771f016ab21f53069a898e642d3d1385/src/dune_rules/exe.ml#L75).

The dune docs mention how to specify
[linking modes](https://dune.readthedocs.io/en/stable/reference/dune/executable.html#linking-modes)
for executables, so we'll try that.

```
(executables
 (names mod)
 (modes object))
```

After some trial and error, I've figured out that the target corresponding to
this rule is `mod.exe.o`:

```bash
$ dune build --verbose mod.exe.o
...
Actual targets:
- _build/default/mod.exe.o
Running[1]: (cd _build/default && /.../.opam/5.2.1/bin/ocamlc.opt -w @1..3@5..28@31..39@43@46..47@49..57@61..62@67@69-40 -strict-sequence -strict-formats -short-paths -keep-locs -g -bin-annot -bin-annot-occurrences -I .mod.eobjs/byte -no-alias-deps -opaque -o .mod.eobjs/byte/dune__exe__Mod.cmi -c -intf mod.mli)
Running[2]: (cd _build/default && /.../.opam/5.2.1/bin/ocamlopt.opt -w @1..3@5..28@31..39@43@46..47@49..57@61..62@67@69-40 -strict-sequence -strict-formats -short-paths -keep-locs -g -I .mod.eobjs/byte -I .mod.eobjs/native -intf-suffix .ml -no-alias-deps -opaque -o .mod.eobjs/native/dune__exe__Mod.cmx -c -impl mod.ml)
Running[3]: (cd _build/default && /.../.opam/5.2.1/bin/ocamlopt.opt -w @1..3@5..28@31..39@43@46..47@49..57@61..62@67@69-40 -strict-sequence -strict-formats -short-paths -keep-locs -g -o mod.exe.o -output-complete-obj .mod.eobjs/native/dune__exe__Mod.cmx)
```

I'm not exactly sure if there are better ways to do this, but we manually
define rules to run the remaining steps:

```
(rule
 (targets modwrap.o)
 (deps modwrap.c)
 (action
  (run ocamlopt %{deps})))

(rule
 (targets main.exe)
 (deps main.c mod.exe.o modwrap.o)
 (action
  (run %{cc} -o %{targets} -I %{ocaml_where} %{deps} -lm)))
```

And voila!

```bash
$ dune exec ./main.exe
fib(10) = Result is: 89            
```