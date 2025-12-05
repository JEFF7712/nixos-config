{ pkgs, lib, config, ... }: {
  options.firefox.enable = lib.mkEnableOption "firefox";

  config = lib.mkIf config.firefox.enable {
    programs.firefox.enable = true;
  };
}
