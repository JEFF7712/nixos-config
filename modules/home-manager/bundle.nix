{ pkgs, lib, ... }:

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
    ./profiles/noctalia.nix
    ./profiles/nord.nix
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

  home.sessionPath = [ "$HOME/.local/bin" ];
}
