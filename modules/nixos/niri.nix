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

    # No global LIBVA / GLX nvidia vendor: that defeats PRIME offload.
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
    services.upower.enable = true;
  };
}
