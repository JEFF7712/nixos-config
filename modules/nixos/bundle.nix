{ pkgs, lib, ... }: {

  imports = [
    ./nvidia.nix
    ./niri.nix
    ./git.nix
    ./filemanager.nix
    ./general-laptop.nix
    ./audio.nix
    ./bluetooth.nix
    ./ctls.nix
    ./tailscale.nix
    ./distrobox.nix
    ./podman.nix
    ./file-utils.nix
    ./docker.nix
    ./netbird.nix
    ./waydroid.nix
  ];

  git.enable = lib.mkDefault true;

}
