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

  programs.fish = {
    shellAliases = {
      bnix="cd $HOME/nixos && git add . && sudo nixos-rebuild switch --flake .#general-device && git commit -m 'Updates' && git push";
    };
  };

  qt = {
    enable = true;
  };

}
