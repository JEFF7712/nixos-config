{ inputs, pkgs, lib, config, ... }: {

  options = {
    niri.enable = lib.mkEnableOption "user niri config"; 
  };

  config = lib.mkIf config.niri.enable {

    home.packages = with pkgs; [
      grim
      slurp
      swww
      wl-clipboard
      eza 
      bat
      tealdeer
      fzf
      nwg-look
      kdePackages.qt6ct
      adw-gtk3
      kitty
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
    
    xdg.configFile."niri".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/niri";
    xdg.configFile."kitty".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/kitty";
    xdg.configFile."gtk-2.0".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/gtk-2.0";
    xdg.configFile."gtk-3.0".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/gtk-3.0";
    xdg.configFile."gtk-4.0".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/gtk-4.0";
    xdg.configFile."qt5ct".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/qt5ct";    
    xdg.configFile."qt6ct".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/qt6ct";
  };
}
