{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.niri.enable = lib.mkEnableOption "niri window manager";

  config = lib.mkIf config.niri.enable {

    programs.niri = {
      enable = true;
    };

    services.gnome.gnome-keyring.enable = true;

    environment.systemPackages = with pkgs; [
      libnotify
      xwayland-satellite
      alacritty
    ];

    # No global LIBVA_DRIVER_NAME / __GLX_VENDOR_LIBRARY_NAME: forcing the
    # nvidia vendor session-wide defeats PRIME offload — every GLX app renders
    # on the dGPU and keeps it awake. Per-app offload env lives in the game
    # aliases; NVD_BACKEND only applies when something opts into nvidia VAAPI.
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      NVD_BACKEND = "direct";
    };
    services.upower.enable = true;
  };
}
