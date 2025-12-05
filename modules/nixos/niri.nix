{ pkgs, lib, config, ... }: {

  options = {
    niri.enable = lib.mkEnableOption "enables niri window manager";
  };

  config = lib.mkIf config.niri.enable {
    
    programs.niri.enable = true;

    services.gnome.gnome-keyring.enable = true;

    environment.systemPackages = with pkgs; [
      waybar
      mako
      libnotify
      swww
      fuzzel
      xwayland-satellite
    ];

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
