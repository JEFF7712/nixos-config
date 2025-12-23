{ pkgs, lib, ... }: {
  imports = [
    ./common-apps.nix
    ./heavy-apps.nix
    ./niri.nix
    ./terminal.nix
    ./noctalia.nix
    ./cli/cli-toys.nix
    ./cli/cli-tools.nix
    ./dev.nix
  ];

  niri.enable = lib.mkDefault true;
  noctalia.enable = lib.mkDefault true;
  terminal.enable = lib.mkDefault true;

  home.file.".local/bin" = {
    source = ./scripts;
    recursive = true;
    executable = true;
  };

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

}
