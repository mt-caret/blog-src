---
title: Working Through the Jepsen Tutorial with a NixOS Container Cluster
date: 2020-08-07
category: tech
tags:
- NixOS
- Nix
- Jepsen
---

[Jepsen](https://github.com/jepsen-io/jepsen) is a distributed system testing
library which has
[found numerous issues with existing distributed systems](http://jepsen.io/analyses).
I've always wanted to try it out, but because it was written in an
[unfamiliar language](https://clojure.org/)[^clojure] I couldn't bring myself
to take the plunge. A few outages and some frightening issues later with a
distributed system that we run at work, I finally took some time to
[learn a bit of Clojure](https://www.braveclojure.com/) and go through the
[excellent tutorial for Jepsen](https://github.com/jepsen-io/jepsen/blob/master/doc/tutorial/index.md).

[^clojure]:
	I distinctly remember trying to learn Clojure and utterly failing back in
	high school. After working with and enjoying the ML family of languages and
	its descendants (OCaml, F#, Haskell, etc.) and flipping through SICP, Clojure
	feels much less unfamiliar.

The tutorial is a step-by-step guide on how to create a Jepsen test for
[etcd](https://etcd.io/), a popular key-value based on the
[the Raft consensus algorithm](https://raft.github.io/).
Since we're testing distributed systems, we need multiple systems running,
and Jepsen defaults to requiring five machines accessible in a certain way.
Getting the configuration exactly right took some time to figure out,
so I've created a NixOS configuration module that you can import which will
take care of setting up etcd in NixOS containers correctly:

```nix
{ config, lib, pkgs, ... }:
let
  unstable = import ./unstable.nix;
  addressMap =
    {
      "n1" = { localAddress = "10.233.0.101"; hostAddress = "10.233.1.101"; };
      "n2" = { localAddress = "10.233.0.102"; hostAddress = "10.233.1.102"; };
      "n3" = { localAddress = "10.233.0.103"; hostAddress = "10.233.1.103"; };
      "n4" = { localAddress = "10.233.0.104"; hostAddress = "10.233.1.104"; };
      "n5" = { localAddress = "10.233.0.105"; hostAddress = "10.233.1.105"; };
    };
  toHostsEntry = name: { localAddress, ... }: "${localAddress} ${name}";
  extraHosts =
    builtins.concatStringsSep "\n"
      (lib.attrsets.mapAttrsToList toHostsEntry addressMap);
  nodeConfig = hostName: { localAddress, hostAddress }: {
    inherit localAddress hostAddress;

    ephemeral = true;
    autoStart = true;
    privateNetwork = true;

    config = { config, pkgs, ... }:
      {
        networking = {
          inherit hostName extraHosts;
        };

        services.openssh = {
          enable = true;
          permitRootLogin = "yes";
        };
        users.users.root.initialPassword = "root";

        system.stateVersion = "20.03";

        services.etcd =
          let
            peerUrl = "http://${localAddress}:2380";
            clientUrl = "http://${localAddress}:2379";
            toClusterEntry = name: { localAddress, ... }:
              "${name}=http://${localAddress}:2380";
          in
            {
              enable = true;
              name = hostName;

              initialAdvertisePeerUrls = [ peerUrl ];
              listenPeerUrls = [ peerUrl ];

              advertiseClientUrls = [ clientUrl ];
              listenClientUrls = [ clientUrl "http://127.0.0.1:2379" ];

              initialClusterToken = "etcd-cluster";
              initialCluster =
                lib.attrsets.mapAttrsToList toClusterEntry addressMap;
              initialClusterState = "new";

              # Apparently Jepsen can't read journald logs? Unfortunate.
              extraConf.LOG_OUTPUT = "stderr";
            };

        # Workaround for nixos-container issue
        # (see https://github.com/NixOS/nixpkgs/issues/67265 and
        # https://github.com/NixOS/nixpkgs/pull/81371#issuecomment-605526099).
        # The etcd service is of type "notify", which means that
        # etcd would not be considered started until etcd is fully online;
        # however, since NixOS container networking only works sometime *after*
        # multi-user.target, we forgo etcd's notification entirely.
        systemd.services.etcd.serviceConfig.Type = lib.mkForce "exec";

        systemd.services.etcd.serviceConfig.StandardOutput = "file:/var/log/etcd.log";
        systemd.services.etcd.serviceConfig.StandardError = "file:/var/log/etcd.log";

        networking.firewall.allowedTCPPorts = [ 2379 2380 ];
      };
  };
in
{
  containers = lib.attrsets.mapAttrs nodeConfig addressMap;
  networking = {
    inherit extraHosts;
  };
}
```

As Jepsen doesn't support NixOS natively, a few tweaks were required, but
there were suprisingly few hiccups along the way. Thank you
[aphyr](https://aphyr.com/) for the amazing work! Here's the code that I ended
up with after going through the tutorial here, and encourage you to try it out.

[mt-caret/nixos-jepsen.etcdemo](https://github.com/mt-caret/nixos-jepsen.etcdemo)

I'll probably try setting up a Jepsen test for the distributed system that we
use at work next, and I'm looking forward to blogging about what I learn along
the way.
