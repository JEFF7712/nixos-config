{ inputs, pkgs, lib, config, ... }:

{
  options.niri.enable = lib.mkEnableOption "user niri config";

  config = lib.mkIf config.niri.enable {

    home.packages = with pkgs; [
      grim
      slurp
      swww
      wl-clipboard
      nwg-look
      kdePackages.qt6ct
      adw-gtk3
      waypaper
      rofi
      python3Packages.pywal
      mako
      waybar
    ];


    systemd.user.services.swww = {
      Unit = {
        Description = "Wayland wallpaper daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.swww}/bin/swww-daemon --no-cache";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    xdg.configFile."niri".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/configs/niri";
    xdg.configFile."kitty".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/configs/kitty";
    xdg.configFile."gtk-2.0".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/configs/gtk-2.0";
    xdg.configFile."gtk-3.0".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/configs/gtk-3.0";
    xdg.configFile."gtk-4.0".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/configs/gtk-4.0";
    xdg.configFile."qt5ct".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/configs/qt5ct";
    xdg.configFile."qt6ct".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/home/configs/qt6ct";
  };
}
