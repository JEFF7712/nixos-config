{ pkgs, lib, config, ... }: {
  options.media-apps.enable = lib.mkEnableOption "media apps";

  config = lib.mkIf config.media-apps.enable {
    home.packages = with pkgs; [
      netflix
    ];   
  };
}
