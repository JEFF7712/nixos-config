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
  ];

  nvidia.enable = lib.mkDefault true;
  niri.enable = lib.mkDefault true; 
  git.enable = lib.mkDefault true;

}
