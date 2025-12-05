{ pkgs, lib, config, ... }: {
  options.kitty.enable = lib.mkEnableOption "kitty terminal";

  config = lib.mkIf config.kitty.enable {
    home.packages = [ pkgs.kitty ];

    xdg.configFile."kitty".source = ../configs/kitty;
  };
}
