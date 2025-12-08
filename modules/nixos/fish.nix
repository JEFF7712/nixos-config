{ pkgs, lib, config, ... }: {
  options.fish.enable = lib.mkEnableOption "fish";

  config = lib.mkIf config.fish.enable {
    programs.fish = {
      enable = true;

      shellAliases = {
        gc = "nix-collect-garbage -d";
        bnix="cd $HOME/nixos && git add . && sudo nixos-rebuild switch --flake .#laptop && git commit -m 'Updates' && git push";
        cniri="sudo $EDITOR $HOME/nixos/modules/home-manager/configs/niri/config.kdl";
        ls = "eza --icons";      
        ll = "eza -l --icons";   
        lt = "eza --tree --level=2 --icons"; 
        la = "eza -a --icons";     
        lla = "eza -la --icons"; 
      };

#      interactiveShellInit = ''
#      set -g fish_color_param purple
#      set -g fish_color_valid_path purple
#      '';
    };

    programs.starship = {
      enable = true;
      settings = {

        directory = {
#          style = "bold #aaaaaa"; 
          truncation_length = 8;
          truncate_to_repo = false; # Always show full path
          read_only = " 🔒";
        };
    
        git_branch = {
#	  style = "bold #aaaaaa";
          symbol = "🌱 ";
          truncation_length = 4;
          truncation_symbol = "";
        };
      };
    };

    environment.systemPackages = with pkgs; [ 
      eza 
      bat
    ];

    users.users.rupan.shell = pkgs.fish;
  };
}
