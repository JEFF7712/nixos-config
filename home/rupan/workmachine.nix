{ pkgs, ... }:
{
  imports = [
    ./home.nix
    ../../modules/home-manager/niri.nix 
  ];

  niri.enable = true;
}
