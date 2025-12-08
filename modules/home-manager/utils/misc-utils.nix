{ pkgs, lib, config, ... }: {
  options.misc-utils.enable = lib.mkEnableOption "misc utils";

  config = lib.mkIf config.misc-utils.enable {
    home.packages = with pkgs; [
      wl-clipboard
    ];
  };
}
