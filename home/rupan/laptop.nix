{ pkgs, ... }:
{
  imports = [
    ./home.nix
    ../../modules/home-manager/default.nix 
  ];

  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    hack-font

    flat-remix-gtk
    papirus-icon-theme
    adwaita-icon-theme
    fluent-icon-theme
    
    libsForQt5.qtstyleplugin-kvantum
    qt6Packages.qtstyleplugin-kvantum
  ];
  
  firefox.enable = true;
  vscode.enable = true;
  spicetify.enable = true;
  niri.enable = true;
  fuzzel.enable = true;
  waybar.enable = true;
  alacritty.enable = true;
  kitty.enable = true;
  swww.enable = true;
  waypaper.enable = true;
  cli-toys.enable = true;
  direnv.enable = true;
  rofi.enable = true;
  media-apps.enable = true;
  bitwarden-cli.enable = true;


  gtk = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };
    theme = {
      name = "Flat-Remix-GTK-Grey-Darkest";
      package = pkgs.flat-remix-gtk;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Adwaita";
      size = 28;
      package = pkgs.adwaita-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-toolbar-style = "GTK_TOOLBAR_BOTH_HORIZ";
      gtk-toolbar-icon-size = "GTK_ICON_SIZE_LARGE_TOOLBAR";
      gtk-button-images = 0;
      gtk-menu-images = 0;
      gtk-enable-event-sounds = 1;
      gtk-enable-input-feedback-sounds = 0;
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle = "hintslight";
      gtk-xft-rgba = "none";
    };
    gtk4.extraConfig = {
      gtk-enable-event-sounds = 1;
      gtk-xft-antialias = 1;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk"; 
    style.name = "kvantum";
  };

  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=Flat-Remix-GTK-Grey-Darkest
  '';

}
