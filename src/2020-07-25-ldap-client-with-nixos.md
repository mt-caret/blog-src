---
title: "Setting up LDAP Authentication with NixOS"
date: 2020-07-25
category: tech
tags:
- NixOS
- Nix
uuid: 851f141b-f08b-4f40-b849-ed32070a3053
---

At work, we manage an OpenLDAP server that handles authentication and
authorization for various services that we provide. All machines run Ubuntu
with individual service being containerized and run in LXD. I was interested
in testing some open source projects out to integrate into our infrastructure.

However, finding out the convoluted installation instructions for software on Ubuntu
and turning it into a provisioning script is always a bit of a pain, so I
decided to use NixOS this time to quickly try it out. The requirements were
fairly involved, though.

- The service needs to run containerized on LXD
- *Only* the users in the `admin` LDAP group should be able to
  - ssh in, with automatic home directory creation
  - access a web interface via HTTPS[^ports]

[^ports]:
	We either expose relevant ports via
	[LXD proxy devices](https://lxd.readthedocs.io/en/latest/instances/#type-proxy),
	or directly expose the containers to the network using
	[macvlan](https://lxd.readthedocs.io/en/latest/networks/#network-macvlan).
	For the purposes of this post, you can follow along with the assumption
	that the HTTP and HTTPS ports of the containers are accessible from the
	Internet at `www.example.com`.

I'll go through the steps I took to meet each requirement, one by one.

# Setting up a NixOS LXD container

(If you're not interested in LXD, you can just skip to
[LDAP Authentication](#ldap-authentication))

Thanks to
[nix-community/nixos-generators](https://github.com/nix-community/nixos-generators),
this is [pretty straightforward](https://www.srid.ca/2012301.html). First, we
want to start off with a configuration that's similar to that found in Ubuntu
LXD images:

```nix
# configuration.nix
{ config, pkgs, ... }:
{
  # https://github.com/NixOS/nixpkgs/issues/9735#issuecomment-500164017
  systemd.services."console-getty".enable = false;
  systemd.services."getty@".enable = false;

  imports = [
    <nixpkgs/nixos/modules/virtualisation/lxc-container.nix>
  ];
  networking.hostName = "nixos";

  services.openssh = {
    enable = true;
    permitRootLogin = "no";
  };

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    vim
    htop
    tmux
    wget
  ];

  networking.useDHCP = true;
}
```

With this, we can create an LXD image with the following command:

```bash
nix-shell -p nixos-generators --run \
  'lxc image import --alias nixos \
    $(nixos-generate --format lxc-metadata --configuration ./configuration.nix) \
    $(nixos-generate --format lxc --configuration ./configuration.nix)'
```

Now that we've created an image under the alias `nixos`, we can launch a
NixOS container with
`lxc launch nixos nixos-test -c security.nesting=true`.

Once an alias is defined like this:

```bash
lxc alias add nixos 'exec @ARGS@ --mode interactive -- /run/current-system/sw/bin/login -p -f nixos'
```

Logging into a running NixOS container is as simple as `lxc nixos nixos-test`.
We can now fill in `/etc/nixos/configuration.nix` and
`sudo nixos-rebuild switch` as needed.

# LDAP Authentication

Setting up LDAP authentication was... not as straightforward as I'd hoped.

## First Attempt

Let's forget about group authorization for a moment, and try to get LDAP-based
ssh logins working.

```nix
{ lib, config, pkgs, ... }:
{
  users.ldap = {
    enable = true;
    base = "dc=example,dc=com";
    server = "ldap://example.com/";
    useTLS = true;
    extraConfig = ''
      ldap_version 3
      pam_password md5
    '';
  };

  security.pam.services.sshd.makeHomeDir = true;
}
```

Note that the LDAP server we are using is configured to allow anonymous binding
and authentication, which may not fit your use-case.

Unfortunately, this doesn't work; attempting to login as a LDAP user gives
errors like the following:

```plaintext
Jul 24 10:51:23 nixos sshd[11992]: Postponed keyboard-interactive for invalid user nixos-user from a.b.c.d port 59828 ssh2 [preauth]
Jul 24 10:51:25 nixos sshd[11994]: pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=a.b.c.d  user=nixos-user
Jul 24 10:51:25 nixos sshd[11994]: pam_ldap: error trying to bind as user "uid=nixos-user,ou=Users,dc=example,dc=com" (Invalid credentials)
Jul 24 10:51:26 nixos sshd[11992]: error: PAM: Authentication failure for illegal user nixos-user from a.b.c.d
```

This is frustratingly misleading since the real culprit is this, slightly
preceding, message from sshd:

```
Jul 24 10:51:23 nixos sshd[11992]: User nixos-user not allowed because shell /bin/bash does not exist
```

This occurs because in our LDAP server, we had set users' LDAP loginShell
attribute to `/bin/bash`. In hindsight, I don't think this was such a
bad a thing to do, considering that I've never dealt with a single system in
which `/bin/bash` doesn't exist (with the exception of NixOS, of course :smile:
).

## Second Attempt

[The standard approach](https://serverfault.com/a/137996) to solving this
problem is configuring the LDAP client to override the relevant attribute:

```nix
...
{
  users.ldap = {
    ...
    extraConfig = ''
      ...

      nss_override_attribute_value loginShell /run/current-system/sw/bin/bash
    '';
  };
  ...
}
```

Unfortunately, this doesn't seem to solve the issue, and sshd continues to
complain about `/bin/bash` missing.[^override-attribute]

[^override-attribute]:
	If you know how to fix this, please let me know!

This seems to leave us with changing the `loginShell` attributes to `/bin/sh`,
since that's the only way to accommodate NixOS systems while maintaining
compatibility with the non-NixOS systems also using LDAP. But `/bin/sh` isn't a
nice shell to work in, so do we really want to force this on everyone across
all machines? Well, there is one easy trick to make this all go away; just
symlink `/bin/bash` to `/run/current-system/sw/bin/bash`
[:gasp:](https://discourse.nixos.org/t/add-bin-bash-to-avoid-unnecessary-pain/5673/38).

```nix
{ lib, config, pkgs, ... }:
{
  users.ldap = {
    enable = true;
    base = "dc=example,dc=com";
    server = "ldap://example.com/";
    useTLS = true;
    extraConfig = ''
      ldap_version 3
      pam_password md5

      # TOFIX: this does not work for some reason
      # # https://serverfault.com/a/137996
      # nss_override_attribute_value loginShell /run/current-system/sw/bin/bash
    '';
  };

  # evil, horrifying hack for dysfunctional nss_override_attribute_value
  systemd.tmpfiles.rules = [
    "L /bin/bash - - - - /run/current-system/sw/bin/bash"
  ];
}
```

## Group-based Authorization and Home Directory Creation

LDAP group-based authorization was also not as straightforward as I'd hoped.
Adding `pam_groupdn cn=admin,ou=Groups,dc=example,dc=com` to
`users.ldap.extraConfig` only seems to work when users solely belong to the
`admin` group, which was not the case for us. Instead, using `pam_listfile.so`
got us what we wanted:

```nix
...
{
  ...
  security.pam.services.sshd = {
    makeHomeDir = true;

    # see https://stackoverflow.com/a/47041843 for why this is required
    text = lib.mkDefault (
      lib.mkBefore ''
        auth required pam_listfile.so \
          item=group sense=allow onerr=fail file=/etc/allowed_groups
      ''
    );
  };

  environment.etc.allowed_groups = {
    text = "admins";
    mode = "0444";
  };
  ...
}
```

## LDAP Authentication for Nginx

This is actually just a variation on
[the example for PAM authentication for Nginx on the NixOS Wiki](https://nixos.wiki/wiki/Nginx#Authentication_via_PAM)
used along with `pam_listfile.so`:

```nix
...
{
  ...
  services.nginx = {
    enable = true;
    package = (pkgs.nginx.override { modules = [ pkgs.nginxModules.pam ]; });
    virtualHosts."www.example.com" = {
      enableACME = true;
      forceSSL = true;
      ...
      extraConfig = ''
        auth_pam "LDAP Authentication Required";
        auth_pam_service_name "nginx";
      '';
    };
  };
  security.pam.services.nginx.text = ''
    auth    required     pam_listfile.so \
                         item=group sense=allow onerr=fail file=/etc/allowed_groups
    auth    required     ${pkgs.pam_ldap}/lib/security/pam_ldap.so
    account required     ${pkgs.pam_ldap}/lib/security/pam_ldap.so
  '';
  ...
}
```

With this configuration, accesses to `www.example.com` will be authenticated
with HTTP Basic Authentication backed by the same LDAP group-based policy.

# Wrapping Up

After working through a fairly involved example of deploying NixOS into
conventional infrastructure, I'm left with the impression that there's a lot
more we can do to make the experience working with mundane things like LDAP
much better. I would love to see NixOS becoming the sysadmin's favorite
distribution, as it definitely has the potential to become so.

<small>
Thanks to \_\_pandaman64\_\_ for comments and suggestions.
</small>
