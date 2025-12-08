{ pkgs, lib, config, ... }: {
  options.obs-studio.enable = lib.mkEnableOption "obs studio";

  config = lib.mkIf config.obs-studio.enable {
    home.packages = with pkgs; [
      obs-studio
    ];   
  };
}
