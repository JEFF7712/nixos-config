{ pkgs, lib, ... }: {
  imports = [
    ./desktop-apps/vscode.nix
    ./desktop-apps/spicetify.nix
    ./desktop-apps/firefox.nix
    ./desktop-environment/niri.nix
    ./desktop-environment/fuzzel.nix
    ./desktop-environment/waybar.nix
    ./desktop-environment/swww.nix 
    ./desktop-environment/waypaper.nix
    ./terminals/alacritty.nix
    ./terminals/kitty.nix
    ./cli/cli-toys.nix
    ./dev/direnv.nix
  ];

  niri.enable = lib.mkDefault true;
  alacritty.enable = lib.mkDefault true;
}
