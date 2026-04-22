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
      with pkgs;
      [
        tmux
        btop
        ffmpeg
        parted
        smartmontools
        ncdu
        yazi
      ]
      ++ [
        inputs.compchem-cctop.packages.${pkgs.system}.default
      ];
  };
}
