{ pkgs, lib, config, ... }:

{
  options.waydroid.enable = lib.mkEnableOption "waydroid";

  config = lib.mkIf config.waydroid.enable {
    environment.systemPackages = with pkgs; [ waydroid android-tools ];
    virtualisation.waydroid.enable = true;
    users.users.rupan.extraGroups = [ "kvm" "adbusers" ];
  };
}
