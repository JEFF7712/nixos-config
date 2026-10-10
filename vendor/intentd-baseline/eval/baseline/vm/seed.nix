# Seeds /etc/nixos on first boot so the agent under test has a real, writable
# flake to edit.
#
# `nixos-rebuild build-vm` does not populate /etc/nixos in the guest, and
# nix-agent has no remote/--target-host mode (it shells out to a local
# `sudo nixos-rebuild`), so the agent session runs INSIDE this VM against a
# local checkout. Without this unit there is nothing at /etc/nixos for it to
# resolve (nix-agent's target resolution tries $NIX_AGENT_FLAKE, then
# /etc/nixos first among the default search paths).
#
# This module is imported only by ../flake.nix, never by the seeded copy: see
# the header of ./seed-flake.nix for why the agent's own configuration must
# not carry it.
{ pkgs, ... }:
let
  seedDir = pkgs.runCommand "baseline-etc-nixos" { } ''
    mkdir -p "$out"
    cp ${./seed-flake.nix} "$out/flake.nix"
    cp ${./flake.lock} "$out/flake.lock"
    cp ${./configuration.nix} "$out/configuration.nix"
    cp ${./agent-harness.nix} "$out/agent-harness.nix"
    cp ${./cursor-mcp-timeout-patch.py} "$out/cursor-mcp-timeout-patch.py"
    cp ${./mcp-preflight.py} "$out/mcp-preflight.py"
    cp ${./nix-agent-launcher.c} "$out/nix-agent-launcher.c"
    cp ${./vm-node.nix} "$out/vm-node.nix"
  '';
in
{
  systemd.services.seed-etc-nixos = {
    description = "Seed /etc/nixos with the baseline flake";
    wantedBy = [ "multi-user.target" ];
    before = [ "sshd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # Guarded on flake.nix rather than on the directory: /etc/nixos may already
    # exist and be empty. Re-running must never clobber the agent's edits, so a
    # second boot of a VM whose disk persisted leaves the work in place.
    path = [ pkgs.nix ];
    script = ''
      if [ ! -e /etc/nixos/flake.nix ]; then
        mkdir -p /etc/nixos
        cp ${seedDir}/flake.nix ${seedDir}/flake.lock \
           ${seedDir}/configuration.nix ${seedDir}/agent-harness.nix \
           ${seedDir}/cursor-mcp-timeout-patch.py \
           ${seedDir}/mcp-preflight.py \
           ${seedDir}/nix-agent-launcher.c ${seedDir}/vm-node.nix /etc/nixos/
        chmod -R u+w,g+w /etc/nixos
        chown -R wedge:users /etc/nixos
      fi

      # Register the pristine booted system as system generation 1.
      #
      # A VM booted straight from the store (virtualisation.useBootLoader =
      # false) has an EMPTY system profile: the first `nixos-rebuild switch`
      # the agent runs becomes generation 1, so the pristine state is not a
      # generation and there is nothing under it to roll back to. That breaks
      # task 5 two ways: `nixos-rebuild list-generations` (the PROTOCOL
      # section 3.2 step 5 check) shows only the agent's own changes, and an
      # agent that reaches for `--rollback` after a single change finds no
      # predecessor and can fail a task for a harness reason rather than its
      # own behaviour.
      #
      # --set on the already-running closure is instant: it moves the profile
      # pointer, it does not build or activate anything.
      if [ ! -e /nix/var/nix/profiles/system ]; then
        nix-env --profile /nix/var/nix/profiles/system --set "$(readlink -f /run/current-system)"
      fi
    '';
  };
}
