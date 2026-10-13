# Sovereign artifact publication

Forgejo `JEFF7712/nixos-config` owns source and protected Woodpecker validation.
The protected `nixos-publish` operation in Forgejo `JEFF7712/homelab` owns artifact
publication. It verifies the source tip before cloning, builds the laptop
toplevel and installer ISO, and pushes their closures, locked flake sources
and build inputs to local Attic. A missing publishing credential fails closed.

The operator first validates current homelab main in Woodpecker, then triggers
`deploy_to=nixos-publish` from that successful parent. This is a manual operation;
ordinary pushes to nixos-config validate source but do not publish artifacts.
GitHub remains an optional mirror with hosted checks. Its toplevel and ISO
publishing workflows have been removed.

## Accepted publication on 2026-10-13

- Woodpecker homelab pipeline 1600 succeeded, parent validation 1599.
- Homelab source: `e2b399e5d006db4de617b56aee0b1bbe821b66ef`.
- NixOS source: `b4b751ef4bff7c4e3e572b5727e51095215ef459` for both targets.
- Laptop toplevel: `/nix/store/x2d3c595mzv9ix2q2k51d8wia84nxs0g-nixos-system-laptop-nixos-26.11.20260916.b1b8759`.
- ISO output: `/nix/store/hy2bld0gwamakk8qswxm6zcpcdn721p6-nixos-26.11.20260916.b1b8759-x86_64-linux.iso`.

Both target paths were independently evaluated from the exact Forgejo source.
Their Attic signatures were verified against the configured homelab public key.
Both NARs were downloaded off-host and their full SHA-256 hashes and sizes
verified. The control-plane receipt confirms completion but has no output files;
the independent recovery receipt binds the source and downloaded target paths.

Recovery assets and receipt are at
`/home/rupan/sovereign-recovery/nixos/2026-10-13/publication-1600`.
The ISO NAR is a self-contained installer output. The laptop toplevel NAR has
references and does not replace retention of its full dependency closure.
Full laptop closure restoration and actual installer boot remain separate
acceptance tests. No laptop configuration was activated or device flashed.
