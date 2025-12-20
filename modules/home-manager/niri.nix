{ inputs, pkgs, lib, config, ... }: {

  options = {
    niri.enable = lib.mkEnableOption "user niri config"; 
  };

  imports = [
    inputs.noctalia.homeModules.default
  ];

  config = lib.mkIf config.niri.enable {

    home.packages = with pkgs; [
      grim
      slurp
      wl-clipboard
      rofi
      swww
      waypaper
      eza 
      bat
      tealdeer
      fzf
      inputs.noctalia.packages.${pkgs.system}.default
    ];

    ## TERMINAL, SHELL, PROMPT CONFIGURATION
    programs.kitty = {
      enable = true;
      extraConfig = builtins.readFile ./configs/kitty/kitty.conf;
    };
    programs.bash = {
      enable = true;
      initExtra = builtins.readFile ./configs/bashrc/.bashrc;
    };
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
      interactiveShellInit = ''
        set fish_greeting ""
        set -g fish_color_param dddddd 
        set -g fish_color_valid_path aaaaaa 
       
        set -g fish_color_command ffffff      # The command itself (e.g., 'git')
        set -g fish_color_error ff6666        # Keep error a slightly reddish-gray for contrast
        set -g fish_color_quote ffffff        # Strings in quotes
        set -g fish_color_autosuggestion 777777 # Suggestions (a medium gray)
      '';
    };
    home.sessionVariables = {
      EZA_COLORS = builtins.concatStringsSep ":" [
        "di=1;97"
        "fi=97"
        "ln=4;3;97"
        "ex=1;97"
        "ur=2;90" # User Read
        "uw=2;90" # User Write
        "ux=2;90" # User Execute
        "gu=2;90" # Group
        "da=2;90" # Date
        "sn=2;90" # Size numbers
        "sb=2;90" # Size units
        "do=97"   # Documents
        "co=97"   # Compressed files
        "tm=90"   # Temporary files (dimmed)
      ];
    };
    programs.starship = {
      enable = true;
        settings = {
          format = "$all";
          directory = {
            style = "bold #aaaaaa"; 
            truncation_length = 8;
            truncate_to_repo = false;
            read_only = " 🔒"; 
          };
          git_branch = {
            style = "bold #f8f8f2"; 
            symbol = "🌱 ";
            truncation_length = 4;
            truncation_symbol = "";
          };
          character = {
            success_symbol = "[❯](bold #cccccc)";
            error_symbol = "[✖](bold #ff6666)";
          };
          nix_shell = {
            style = "bold #aaaaaa";
            symbol = "❄️ ";
          };
      };
    };
    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    services.mako = {
      enable = true;
      settings = {
        font = "JetBrains Mono 10"; 
        "background-color" = "#101010cc";
        "text-color" = "#eeeeeecc";
        "border-color" = "#303030cc";
        "border-size" = 1;
        "border-radius" = 3;
        width = 400;
        height = 125;
        margin = "10";
        padding = "15";
        "default-timeout" = 5000;
        layer = "overlay";
        anchor = "top-right";
	      "output=DP-1" = {
          width = 500;
	        height = 150;
          font = "JetBrains Mono 12";
        };
      };
    };

    services.batsignal = {
      enable = true;
      extraArgs = [
        "-w" "30"
        "-c" "10"
        "-d" "5"
        "-m" "Battery Low" 
      ];
    }; 

    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
      settings = {
        screenshots = true;
        indicator = true;
	      effect-scale = 0.5;  
        effect-blur = "7x4";
        effect-vignette = "0.1:0.3";
        indicator-radius = 100; 
        indicator-thickness = 10; 
        inside-color = "00000000"; 
        inside-clear-color = "00000000"; 
        inside-ver-color = "00000000"; 
        inside-wrong-color = "00000000"; 
        key-hl-color = "ffffff"; 
        bs-hl-color = "ffffff"; 
        ring-color = "101010"; 
        ring-wrong-color = "c50000"; 
        ring-ver-color = "1db954"; 
        line-uses-ring = true; 
        line-color = "00000000"; 
        font = "JetBrainsMono Nerd Font"; 
        font-size = 40;  	
        text-color = "00000000"; 
        text-clear-color = "00000000"; 
        text-wrong-color = "00000000"; 
        text-ver-color = "00000000"; 
        separator-color = "00000000"; 
      };
    };

    services.swayidle = {
      enable = true;
      events = {
        before-sleep = "${pkgs.swaylock-effects}/bin/swaylock -fF";
        lock = "${pkgs.swaylock-effects}/bin/swaylock -fF";
      };
      timeouts = [
        { 
          timeout = 300; 
          command = "${pkgs.swaylock-effects}/bin/swaylock -fF"; 
        }
        {
          timeout = 600;
          command = "${pkgs.systemd}/bin/systemctl suspend";
        }
      ];
    };

    systemd.user.services.swww = {
      Unit = {
        Description = "Wayland wallpaper daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.swww}/bin/swww-daemon";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
    
    home.file.".local/bin/wallpaper-random" = {
      executable = true;
      text = ''
        #!/bin/sh
        if [ -d ~/media/images/wallpapers ]; then
          ${pkgs.swww}/bin/swww img $(find ~/media/images/wallpapers -type f | shuf -n 1) --transition-type fade --transition-pos 0.5,0.5 --transition-step 90
        fi
      '';
    };

    programs.waybar = {
      enable = true;
    };  

    systemd.user.services.wallpaper-cycler = {
      Unit = {
        Description = "Cycle wallpaper randomly using waypaper";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.waypaper}/bin/waypaper --random";
      };
    };

    systemd.user.timers.wallpaper-cycler = {
      Unit = {
        Description = "Timer to cycle wallpaper every hour";
      };
      Timer = {
        OnBootSec = "5m"; 
        OnUnitActiveSec = "1h"; 
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
    
    xdg.configFile."niri/config.kdl".source = ./configs/niri/config.kdl;
    xdg.configFile."rofi".source = ./configs/rofi;
    xdg.configFile."noctalia/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/noctalia/settings.json";

  };
}
