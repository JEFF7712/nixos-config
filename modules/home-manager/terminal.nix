{ inputs, pkgs, lib, config, ... }:

{
  options.terminal.enable = lib.mkEnableOption "user terminal config";

  config = lib.mkIf config.terminal.enable {

    home.packages = with pkgs; [
      eza 
      bat
      tealdeer
      fzf
      kitty
    ];

    programs.bash = {
      enable = true;
      initExtra = builtins.readFile ./configs/bashrc/.bashrc;
    };
    programs.fish = {
      enable = true;
      shellAliases = {
        gc = "nix-collect-garbage -d";
        cniri="sudo $EDITOR $HOME/nixos/modules/home-manager/configs/niri/config.kdl";
        ls = "eza --icons";      
        ll = "eza -l --icons";   
        lt = "eza --tree --level=2 --icons"; 
        la = "eza -a --icons";     
        lla = "eza -la --icons"; 
        cd = "z";
        cds = "zi";
        tf="terragrunt";
        k="kubectl";
        kprune="kubectl delete pods -A --field-selector=status.phase=Failed,status.phase=Succeeded";
      };
      interactiveShellInit = ''
        set fish_greeting ""
        set -gx STARSHIP_CONFIG $HOME/.config/starship_matugen.toml
      '';
    };

    programs.starship = {
      enable = true;
    };
    
    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
