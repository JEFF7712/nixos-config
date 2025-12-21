{ pkgs, ... }:
{
  imports = [
    ./home.nix
    ../../modules/home-manager/niri.nix 
    ../../modules/home-manager/common-apps.nix 
    ../../modules/home-manager/cli/cli-tools.nix
    ../../modules/home-manager/cli/cli-toys.nix  

  ];

  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    papirus-icon-theme
  ];
  

  niri.enable = true;
  common-apps.enable = true;
  cli-toys.enable = true;
  cli-tools.enable = true;

  qt = {
    enable = true;
  };

}
