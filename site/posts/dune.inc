; post generation rules
(rule
 (deps ../../tools/bin/tools.exe (glob_files ../../templates/post.html/*.html) ../../src/2020-06-29-optin-state.md ../git-revision)
 (targets 2020-06-29-optin-state.html)
 (action
  (run
    ../../tools/bin/tools.exe
    build-post
    ../../src/2020-06-29-optin-state.md
    2020-06-29-optin-state.html
    -git-revision "%{read-lines:../git-revision}"
    -template ../../templates/post.html
    )))
(rule
 (deps ../../tools/bin/tools.exe (glob_files ../../templates/post.html/*.html) ../../src/2020-07-25-ldap-client-with-nixos.md ../git-revision)
 (targets 2020-07-25-ldap-client-with-nixos.html)
 (action
  (run
    ../../tools/bin/tools.exe
    build-post
    ../../src/2020-07-25-ldap-client-with-nixos.md
    2020-07-25-ldap-client-with-nixos.html
    -git-revision "%{read-lines:../git-revision}"
    -template ../../templates/post.html
    )))
(rule
 (deps ../../tools/bin/tools.exe (glob_files ../../templates/post.html/*.html) ../../src/2020-08-07-jepsen-nixos-containers.md ../git-revision)
 (targets 2020-08-07-jepsen-nixos-containers.html)
 (action
  (run
    ../../tools/bin/tools.exe
    build-post
    ../../src/2020-08-07-jepsen-nixos-containers.md
    2020-08-07-jepsen-nixos-containers.html
    -git-revision "%{read-lines:../git-revision}"
    -template ../../templates/post.html
    )))
(rule
 (deps ../../tools/bin/tools.exe (glob_files ../../templates/post.html/*.html) ../../src/2021-06-19-bootstrapping-nix-channels-in-nixos.md ../git-revision)
 (targets 2021-06-19-bootstrapping-nix-channels-in-nixos.html)
 (action
  (run
    ../../tools/bin/tools.exe
    build-post
    ../../src/2021-06-19-bootstrapping-nix-channels-in-nixos.md
    2021-06-19-bootstrapping-nix-channels-in-nixos.html
    -git-revision "%{read-lines:../git-revision}"
    -template ../../templates/post.html
    )))
(rule
 (deps ../../tools/bin/tools.exe (glob_files ../../templates/post.html/*.html) ../../src/2024-11-09-static-site-generation-in-dune.md ../git-revision)
 (targets 2024-11-09-static-site-generation-in-dune.html)
 (action
  (run
    ../../tools/bin/tools.exe
    build-post
    ../../src/2024-11-09-static-site-generation-in-dune.md
    2024-11-09-static-site-generation-in-dune.html
    -git-revision "%{read-lines:../git-revision}"
    -template ../../templates/post.html
    )))

; aggregation alias
(alias
  (name default)
  (deps 2020-06-29-optin-state.html 2020-07-25-ldap-client-with-nixos.html 2020-08-07-jepsen-nixos-containers.html 2021-06-19-bootstrapping-nix-channels-in-nixos.html 2024-11-09-static-site-generation-in-dune.html))
  
