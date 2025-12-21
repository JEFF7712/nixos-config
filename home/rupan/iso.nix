{ pkgs, ... }:
{
  imports = [
    ./home.nix
    ../../modules/home-manager/bundle.nix 
  ];

  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    papirus-icon-theme
  ];
  

  niri.enable = true;
  common-apps.enable = true;
  cli-toys.enable = true;
  cli-tools.enable = true;
  dev.enable = true;

  programs.fish = {
    shellAliases = {
      bnix="cd $HOME/nixos && git add . && sudo nixos-rebuild switch --flake .#laptop && git commit -m 'Updates' && git push";
    };
  };

  qt = {
    enable = true;
  };

}
