{ pkgs, lib, config, ... }: {
  options = {
    niri.enable = lib.mkEnableOption "niri window manager";
  };

  config = lib.mkIf config.niri.enable {
    
    programs.niri.enable = true;
    services.gnome.gnome-keyring.enable = true;

    environment.systemPackages = with pkgs; [
      mako
      libnotify
      swww
      xwayland-satellite
      swaylock
    ];

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
