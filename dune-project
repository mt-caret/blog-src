(lang dune 3.17)

(name blog)

(package
 (name blog)
 (synopsis "Blog source")
 (allow_empty)
 (depends
  (ocaml
   (>= 5.2))
  dune
  core
  core_unix
  ppx_jane
  ppx_yojson_conv
  shexp
  (yojson
   (< 3.0.0))
  yocaml_syndication))
