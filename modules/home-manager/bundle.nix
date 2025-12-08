{ pkgs, lib, ... }: {
  imports = [
    ./desktop-apps/vscode.nix
    ./desktop-apps/spicetify.nix
    ./desktop-apps/firefox.nix
    ./desktop-apps/media-apps.nix
    ./desktop-apps/bitwarden.nix
    ./desktop-apps/davinci-resolve.nix
    ./desktop-apps/obs-studio.nix
    ./desktop-environment/niri.nix
    ./terminals/alacritty.nix
    ./terminals/kitty.nix
    ./cli/cli-toys.nix
    ./dev/direnv.nix
  ];

  niri.enable = lib.mkDefault true;
  alacritty.enable = lib.mkDefault true;

  home.file.".local/bin" = {
    source = ./scripts;
    recursive = true;
    executable = true;
  };

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

}
