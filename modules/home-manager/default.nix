{ pkgs, lib, ... }: {
  imports = [
    ./desktop-apps/vscode.nix
    ./desktop-apps/spicetify.nix
    ./desktop-environment/niri.nix
    ./desktop-environment/fuzzel.nix
    ./desktop-environment/waybar.nix
    ./desktop-environment/swww.nix 
    ./desktop-environment/waypaper.nix
    ./terminals/alacritty.nix
    ./terminals/kitty.nix
  ];

  vscode.enable = lib.mkDefault true;
  spicetify.enable = lib.mkDefault true;
  niri.enable = lib.mkDefault true;
  fuzzel.enable = lib.mkDefault true;
  waybar.enable = lib.mkDefault true;
  alacritty.enable = lib.mkDefault true;
  kitty.enable = lib.mkDefault true;
  swww.enable = lib.mkDefault true;
  waypaper.enable = lib.mkDefault true;
}
