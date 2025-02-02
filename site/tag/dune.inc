; tag index generation rules

(rule
 (deps ../../tools/bin/tools.exe (source_tree ../../src) (glob_files ../../templates/*.html) ../git-revision)
 (action
  (with-stdout-to
   Jepsen.html
   (run
    ../../tools/bin/tools.exe
    build-index
    ../../src
    -tag Jepsen
    -git-revision "%{read-lines:../git-revision}"
    -template ../../templates/index.html
    -root-dir ..
    ))))

(rule
 (deps ../../tools/bin/tools.exe (source_tree ../../src) (glob_files ../../templates/*.html) ../git-revision)
 (action
  (with-stdout-to
   Nix.html
   (run
    ../../tools/bin/tools.exe
    build-index
    ../../src
    -tag Nix
    -git-revision "%{read-lines:../git-revision}"
    -template ../../templates/index.html
    -root-dir ..
    ))))

(rule
 (deps ../../tools/bin/tools.exe (source_tree ../../src) (glob_files ../../templates/*.html) ../git-revision)
 (action
  (with-stdout-to
   NixOS.html
   (run
    ../../tools/bin/tools.exe
    build-index
    ../../src
    -tag NixOS
    -git-revision "%{read-lines:../git-revision}"
    -template ../../templates/index.html
    -root-dir ..
    ))))

(rule
 (deps ../../tools/bin/tools.exe (source_tree ../../src) (glob_files ../../templates/*.html) ../git-revision)
 (action
  (with-stdout-to
   OCaml.html
   (run
    ../../tools/bin/tools.exe
    build-index
    ../../src
    -tag OCaml
    -git-revision "%{read-lines:../git-revision}"
    -template ../../templates/index.html
    -root-dir ..
    ))))

(rule
 (deps ../../tools/bin/tools.exe (source_tree ../../src) (glob_files ../../templates/*.html) ../git-revision)
 (action
  (with-stdout-to
   dune.html
   (run
    ../../tools/bin/tools.exe
    build-index
    ../../src
    -tag dune
    -git-revision "%{read-lines:../git-revision}"
    -template ../../templates/index.html
    -root-dir ..
    ))))

; aggregation alias
(alias
  (name default)
  (deps Jepsen.html Nix.html NixOS.html OCaml.html dune.html))
  
