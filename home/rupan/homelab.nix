{ pkgs, ... }:

{
  imports = [
    ./home.nix
    ../../modules/home-manager/bundle.nix
  ];

  cli-toys.enable = true;
  dev.enable = true;

  programs.fish.shellAliases.bnix = "cd $HOME/nixos && git add . && sudo nixos-rebuild switch --flake .#homelab && git commit -m 'Updates' && git push";
}
