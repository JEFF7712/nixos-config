{ pkgs, lib, config, ... }: {
  options.waydroid.enable = lib.mkEnableOption "waydroid";

  config = lib.mkIf config.waydroid.enable {
    environment.systemPackages = [
      pkgs.waydroid
    ]; 
    virtualisation.waydroid.enable = true;
  };
}
