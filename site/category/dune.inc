; category index generation rules

(rule
 (deps ../../tools/bin/tools.exe (source_tree ../../src) (glob_files ../../templates/*.html) ../git-revision)
 (action
  (with-stdout-to
   tech.html
   (run
    ../../tools/bin/tools.exe
    build-index
    ../../src
    -category tech
    -git-revision "%{read-lines:../git-revision}"
    -template ../../templates/index.html
    -root-dir ..
    ))))

(rule
 (deps ../../tools/bin/tools.exe (source_tree ../../src) (glob_files ../../templates/*.html) ../git-revision)
 (action
  (with-stdout-to
   uncategorized.html
   (run
    ../../tools/bin/tools.exe
    build-index
    ../../src
    -category uncategorized
    -git-revision "%{read-lines:../git-revision}"
    -template ../../templates/index.html
    -root-dir ..
    ))))

; aggregation alias
(alias
  (name default)
  (deps tech.html uncategorized.html))
  
