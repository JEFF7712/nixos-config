{ pkgs, ... }:
{
  imports = [
    ./home.nix
    ../../modules/home-manager/bundle.nix 
  ];
  
  cli-toys.enable = true;
  direnv.enable = true;

}
