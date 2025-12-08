{ pkgs, lib, config, ... }: {
  options.fish.enable = lib.mkEnableOption "fish";

  config = lib.mkIf config.fish.enable {
    programs.fish = {
      enable = true;
      shellAliases = {
        gc = "nix-collect-garbage -d";
        bnix="cd $HOME/nixos && git add . && sudo nixos-rebuild switch --flake .#laptop && git commit -m 'Updates' && git push";
        cniri="sudo $EDITOR $HOME/nixos/modules/home-manager/configs/niri/config.kdl";
      };
    };

    programs.starship = {
      enable = true;
      settings = {

        directory = {
          style = "bold 005fd7"; 
          truncation_length = 8;
          truncate_to_repo = false; # Always show full path
          read_only = " 🔒";
        };
    
        git_branch = {
	  style = "bold white";
          symbol = "🌱 ";
          truncation_length = 4;
          truncation_symbol = "";
        };
      };
    };

    users.users.rupan.shell = pkgs.fish;
  };
}
