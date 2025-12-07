{ pkgs, lib, config, ... }: {
  options = {
    niri.enable = lib.mkEnableOption "niri window manager";
  };

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

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
