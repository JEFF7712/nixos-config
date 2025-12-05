{ pkgs, lib, ... }: {

  imports = [
    ./nvidia.nix
    ./niri.nix
  ];

  nvidia.enable = lib.mkDefault true;
  niri.enable = lib.mkDefault true; 

}
