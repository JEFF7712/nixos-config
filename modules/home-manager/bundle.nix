{ pkgs, lib, ... }:

{
  imports = [
    ./cli/cli-tools.nix
    ./cli/cli-toys.nix
    ./common-apps.nix
    ./dev.nix
    ./heavy-apps.nix
    ./niri.nix
    ./noctalia.nix
    ./terminal.nix
  ];

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
