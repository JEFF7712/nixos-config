{ inputs, pkgs, lib, config, ... }:

{
  options.terminal.enable = lib.mkEnableOption "user terminal config";
  imports = [ inputs.nixvim.homeManagerModules.nixvim ];

  config = lib.mkIf config.terminal.enable {

    programs.nixvim = {
      enable = true;
      colorschemes.catppuccin.enable = true;
      opts = {
        number = true;
        relativenumber = true;
        shiftwidth = 2;
        expandtab = true;
      };

      plugins = {
        lualine.enable = true;      # Status line
        telescope.enable = true;    # Fuzzy finder
        treesitter.enable = true;   # Better syntax highlighting
        neo-tree.enable = true;     # File explorer
        
        cmp = {
          enable = true;
          settings.sources = [
            { name = "nvim_lsp"; }
            { name = "path"; }
            { name = "buffer"; }
          ];
          settings.mapping = {
            "<C-Space>" = "cmp.mapping.complete()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
          };
        };

        lsp = {
          enable = true;
          servers = {
            nil_ls.enable = true;    # Nix
            pyright.enable = true;   # Python
            clangd.enable = true;    # C/C++
          };
        };
      };
    };

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
        kprune="kubectl delete pods -A --field-selector=status.phase=Failed,status.phase=Succeeded,status.phase==Completed";
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
