{ pkgs, lib, ... }:

{
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./ctls.nix
    ./distrobox.nix
    ./docker.nix
    ./file-utils.nix
    ./filemanager.nix
    ./game.nix
    ./general-laptop.nix
    ./git.nix
    ./netbird.nix
    ./niri.nix
    ./nvidia.nix
    ./podman.nix
    ./waydroid.nix
    ./airplay.nix
    ./vpn.nix
  ];

  git.enable = lib.mkDefault true;
}
