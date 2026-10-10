# Baseline arm system configuration (eval/baseline/PROTOCOL.md section 3.1).
#
# "Plain NixOS": this file deliberately contains no intentd, no product-owned
# flake template, and no capability catalog. It is the configuration a real
# user would hand a coding agent, and the agent edits THIS file (at
# /etc/nixos/configuration.nix inside the VM) to install or remove apps.
#
# It is imported twice, on purpose: once by ./flake.nix to build the VM image
# the human boots, and once by the copy seeded into the VM's own /etc/nixos
# (./seed.nix), so that `nixos-rebuild switch --flake /etc/nixos#baseline`
# inside the VM rebuilds the same system it is already running.
{ pkgs, ... }:
{
  system.stateVersion = "25.11";
  networking.hostName = "baseline";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Force IPv4. qemu's user-mode network stack (slirp) advertises an IPv6
  # prefix (fec0::/64) whose connections complete a TCP handshake and then
  # never move data: `nix` picks the IPv6 address for cache.nixos.org, sits in
  # poll() forever, and the rebuild hangs with no error and no download. curl
  # survives it via happy-eyeballs fallback, so the VM looks online while every
  # nix fetch stalls, which is exactly the failure that is hardest to attribute.
  #
  # This is load-bearing for the measurement, not a convenience: a stalled
  # substituter would be charged to the agent's wall_seconds (PROTOCOL section
  # 5.2) and could read as an abandoned task, turning a harness bug into a
  # baseline-arm result. Seeded rather than set only on the node so the agent's
  # own rebuilds keep it.
  networking.enableIPv6 = false;

  services.openssh.enable = true;

  # Only what a bare machine needs to host an agent session. None of the apps
  # the six tasks ask for is preinstalled: completion is verified with
  # `which`/`test -x` (PROTOCOL section 3.2 step 5), and a preinstalled binary
  # would make task 1 vacuously true.
  #
  # Those app names are deliberately NOT written anywhere in this file. The
  # agent under test reads this configuration before editing it, and a comment
  # listing the exact apps the session is about to ask for would prime it in a
  # way the intentd arm's resolver is not primed (the resolver sees only the
  # utterance and the catalog). Keep task content out of the seeded config.
  environment.systemPackages = with pkgs; [
    git
    curl
    jq
    vim
  ];

  # This configuration only ever runs as a qemu VM booted directly by the
  # `run-baseline-vm` script (virtualisation.useBootLoader stays false), so no
  # bootloader is installed and `nixos-rebuild switch` inside the VM must not
  # try to install one. System generations are still created by the profile
  # switch, so `nixos-rebuild list-generations` (PROTOCOL section 3.2 step 5,
  # the task 5 revert check) reports them normally.
  boot.loader.grub.enable = false;
}
