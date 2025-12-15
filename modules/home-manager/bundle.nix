{ pkgs, lib, ... }: {
  imports = [
    ./desktop-apps.nix
    ./niri.nix
    ./cli/cli-toys.nix
    ./cli/cli-tools.nix
    ./dev.nix
  ];

  niri.enable = lib.mkDefault true;

  home.file.".local/bin" = {
    source = ./scripts;
    recursive = true;
    executable = true;
  };

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

}
