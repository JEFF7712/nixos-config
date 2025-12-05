{ pkgs, ... }:
{
  imports = [
    ./home.nix
    ../../modules/home-manager/default.nix 
  ];

  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

}
