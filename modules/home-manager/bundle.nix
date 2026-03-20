{ pkgs, lib, config, ... }:

{
  imports = [
    ./ai-tools.nix
    ./cli/cli-tools.nix
    ./cli/cli-toys.nix
    ./common-apps.nix
    ./desktop-profiles.nix
    ./dev.nix
    ./heavy-apps.nix
    ./niri.nix
    ./noctalia.nix
    ./profiles/catppuccin.nix
    ./profiles/gruvbox.nix
    ./profiles/noctalia.nix
    ./profiles/nord.nix
    ./profiles/rosepine.nix
    ./terminal.nix
  ];

  desktopProfiles.enable = lib.mkDefault true;
  niri.enable = lib.mkDefault true;
  noctalia.enable = lib.mkDefault true;
  terminal.enable = lib.mkDefault true;

  home.file.".local/bin" = {
    source = ./scripts;
    recursive = true;
    executable = true;
  };

  # Rofi configs (out-of-store so they're editable without rebuild)
  xdg.configFile."rofi".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nixos/modules/home-manager/configs/rofi";

  home.sessionPath = [ "$HOME/.local/bin" ];
}
