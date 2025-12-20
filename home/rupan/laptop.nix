{ pkgs, ... }:
{
  imports = [
    ./home.nix
    ../../modules/home-manager/bundle.nix 
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
  

  niri.enable = true;
  desktop-apps.enable = true;
  cli-toys.enable = true;
  cli-tools.enable = true;
  dev.enable = true;

  qt = {
    enable = true;
    # platformTheme.name = "gtk"; 
    # style.name = "kvantum";
  };

  # xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
  #   [General]
  #   theme=Flat-Remix-GTK-Grey-Darkest
  # '';

}
