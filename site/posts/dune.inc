
(rule
 (deps ../../scripts/build.sh (glob_files ../../templates/*.html) ../../src/2020-06-29-optin-state.md ../git-revision)
 (targets 2020-06-29-optin-state.html)
 (action
  (run ../../scripts/build.sh ../../src/2020-06-29-optin-state.md 2020-06-29-optin-state.html "%{read-lines:../git-revision}")))

(rule
 (deps ../../scripts/build.sh (glob_files ../../templates/*.html) ../../src/2020-07-25-ldap-client-with-nixos.md ../git-revision)
 (targets 2020-07-25-ldap-client-with-nixos.html)
 (action
  (run ../../scripts/build.sh ../../src/2020-07-25-ldap-client-with-nixos.md 2020-07-25-ldap-client-with-nixos.html "%{read-lines:../git-revision}")))

(rule
 (deps ../../scripts/build.sh (glob_files ../../templates/*.html) ../../src/2020-08-07-jepsen-nixos-containers.md ../git-revision)
 (targets 2020-08-07-jepsen-nixos-containers.html)
 (action
  (run ../../scripts/build.sh ../../src/2020-08-07-jepsen-nixos-containers.md 2020-08-07-jepsen-nixos-containers.html "%{read-lines:../git-revision}")))

(rule
 (deps ../../scripts/build.sh (glob_files ../../templates/*.html) ../../src/2021-06-19-bootstrapping-nix-channels-in-nixos.md ../git-revision)
 (targets 2021-06-19-bootstrapping-nix-channels-in-nixos.html)
 (action
  (run ../../scripts/build.sh ../../src/2021-06-19-bootstrapping-nix-channels-in-nixos.md 2021-06-19-bootstrapping-nix-channels-in-nixos.html "%{read-lines:../git-revision}")))

(rule
 (deps ../../scripts/build.sh (glob_files ../../templates/*.html) ../../src/2024-11-09-static-site-generation-in-dune.md ../git-revision)
 (targets 2024-11-09-static-site-generation-in-dune.html)
 (action
  (run ../../scripts/build.sh ../../src/2024-11-09-static-site-generation-in-dune.md 2024-11-09-static-site-generation-in-dune.html "%{read-lines:../git-revision}")))

(alias
  (name default)
  (deps 2020-06-29-optin-state.html 2020-07-25-ldap-client-with-nixos.html 2020-08-07-jepsen-nixos-containers.html 2021-06-19-bootstrapping-nix-channels-in-nixos.html 2024-11-09-static-site-generation-in-dune.html))
  
