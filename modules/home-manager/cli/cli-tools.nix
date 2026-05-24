{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  options.cli-tools.enable = lib.mkEnableOption "cli tools";

  config = lib.mkIf config.cli-tools.enable {
    home.packages =
      let
        system = pkgs.stdenv.hostPlatform.system;
      in
      with pkgs;
      [
        tmux
        btop
        ffmpeg
        parted
        smartmontools
        ncdu
        yazi
        unrar
        inotify-tools
      ]
      ++ [
        inputs.compchem-cctop.packages.${system}.default
        inputs.mercury-cli.packages.${system}.default
      ];
  };
}
