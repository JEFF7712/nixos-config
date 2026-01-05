{ pkgs, lib, config, ... }:

{
  options.cli-tools.enable = lib.mkEnableOption "cli tools";

  config = lib.mkIf config.cli-tools.enable {
    home.packages = with pkgs; [
      tmux
      btop
      ffmpeg
    ];
  };
}
