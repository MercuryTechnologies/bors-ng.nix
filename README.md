# `bors-ng.nix`

This repository provides a `bors-ng` Nix package, which you can install as
either an overlay or as a NixOS module (which includes the overlay).  Both are
exported as output from this repository's `flake.nix`.

You can see an example for how to use the NixOS module by studying
[`vm.nix`](./vm.nix) which shows a sample NixOS VM configuration that puts all
the pieces fit together.  Specifically, that shows how to run `bors-ng` and the
matching `postgresql` backend inside of a NixOS container so that they're
isolated from any other databases running on the same machine.

You can run that VM using:

```ShellSession
$ SECRETS=/path/to/secrets/directory nix run
```

… where that `${SECRETS}`directory contains:

- `secret-key-base.txt`
- `client-secret.txt`
- `private-key.pem`
- `webhook-secret.txt`
