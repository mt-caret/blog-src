---
title: Bootstrapping Nix channels in NixOS
date: 2021-06-19
category: tech
tags:
- NixOS
- Nix
---

A few years after starting to use NixOS, I realized that the experience
of reproducing my setup on a new machine has become *harder*, not easier,
especially after setting up [encryption and opt-in state](./2020-06-29-optin-state.html).
This is rather embarrassing, so here's my first step in remedying that.

My NixOS configuration currently depends on multiple channels (`<nixos-20.09>`,
`<nixos-unstable>`, `<nixpkgs-unstable>`, and
[home-manager](https://github.com/nix-community/home-manager)):

```
https://channels.nixos.org/nixos-20.09/nixexprs.tar.xz nixos
https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz unstable
https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz actual-unstable
https://github.com/nix-community/home-manager/archive/release-20.09.tar.gz home-manager
```

What's painful about this is that on a clean install the various nix channels
aren't present on my machine, and I need to manually set up the required Nix
channels for the root user via the `nix-channel` command or by writing to
`/root/.nix-channels`.  I always forget to do this, and get a variant of the
following error:

```
nix-repl> <foo>
error: file 'foo' was not found in the Nix search path (add it using $NIX_PATH or -I), at (string):1:1
```

The recommended fix I usually hear is to avoid using Nix channels entirely and
[pin the various nixpkgs in configuration.nix](https://github.com/NixOS/nixpkgs/issues/62832).
However, *I don't want to do this*. It's painful to have to update the pin
every so often, and my nixpkgs lags behind Nix channels so I get a lot of
binary cache misses and end up building many packages from source, making the
experience not unlike Gentoo.

On the other hand, doing `builtins.fetchTarball` every time also isn't ideal.
Who wants to require an Internet connect every time you need to change the font
size for your decleratively configured terminal emulator? If we sacrifice just
a bit of determinism (but not too much) we can do better.

In the example above, when the import path `foo` doesn't exist, evaluation of
`<foo>` results in a plain old exception which can be caught with
`builtins.tryEval`:

```nix
let
  resolvedPath = builtins.tryEval <nixos-unstable>;
in
  if resolvedNixPath.success then
    resolvedNixPath.value
  else
    builtins.fetchTarball "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz"
```

By checking if evaluation of the Nix import path threw an exception or not, we
can determine if a particular `import <foo>` succeeded or not. We can then
import nixpkgs normally if the import succeeds, or fall back to fetching a
tarball and importing from there. This can be further extended to automatically
create `.nix-channels` files for root and
[home-manager](https://github.com/nix-community/home-manager) users:

```nix
let
  resolve = nixPath: defaultUrl:
    let
      resolvedNixPath = builtins.tryEval nixPath;
    in
      if resolvedNixPath.success then
        resolvedNixPath.value
      else
        builtins.trace
          "WARNING: could not resolve path, defaulting to '${defaultUrl}'"
          (builtins.fetchTarball defaultUrl);
  channelUrl = channel: "https://channels.nixos.org/${channel}/nixexprs.tar.xz";
  version = "20.09";
  channels = [
    {
      importPath = <nixos>;
      name = "nixos";
      url = channelUrl "nixos-${version}";
    }
    {
      importPath = <unstable>;
      name = "unstable";
      url = channelUrl "nixos-unstable";
    }
    {
      importPath = <actual-unstable>;
      name = "actual-unstable";
      url = channelUrl "nixpkgs-unstable";
    }
  ];
  allNixpkgs =
    builtins.listToAttrs (
      builtins.map (
        { importPath, name, url }:
          {
            inherit name;
            value = import (resolve importPath url) {};
          }
      ) channels
    );
in
allNixpkgs
// rec {
  nix-channels = allNixpkgs.nixos.writeTextFile {
    name = ".nix-channels";
    text =
      builtins.concatStringsSep "\n"
        (builtins.map ({ name, url, ... }: "${url} ${name}") channels);
  };
  home-manager-config = { pkgs, lib, ... }: {
    home.file.".nix-channels".source = nix-channels;
  };
  nixos-config = { ... }: {
    systemd.tmpfiles.rules = [
      # unlike "L", "L+" will remove the existing file if it exists and replace
      # it a symlink
      "L+ /root/.nix-channels - - - - ${nix-channels}"
    ];
  };
}
```

where importing `home-manager-config` for home-manager and `nixos-config` for
root users will just work.

Upgrading the NixOS version just works as well; simply bumping `version` and
running `sudo nixos-rebuild switch --upgrade` twice will do it, where the
first `nixos-rebuild switch` updates the `.nix-channel` file and the second
`nixos-rebuild switch` does the actual upgrading.

I'm pretty happy that I no longer have to think (too hard) about this part of
the clean install process anymore. Unfortunately, since I use
[VirtualBox with the extension pack enabled](https://github.com/NixOS/nixpkgs/issues/34796#issuecomment-413559672),
every time I `nixos-rebuild switch --upgrade` I still get the Gentoo experience
anyway :cry:.
