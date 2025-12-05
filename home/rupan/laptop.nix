{ pkgs, ... }:
{
  imports = [
    ./home.nix
    ../../modules/home-manager/default.nix 
  ];

  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];
  
  firefox.enable = true;
  vscode.enable = true;
  spicetify.enable = true;
  niri.enable = true;
  fuzzel.enable = true;
  waybar.enable = true;
  alacritty.enable = true;
  kitty.enable = true;
  swww.enable = true;
  waypaper.enable = true;
  cli-toys.enable = true;

}
