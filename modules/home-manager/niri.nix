{ inputs, pkgs, lib, config, ... }: {

  options = {
    niri.enable = lib.mkEnableOption "user niri config"; 
  };

  imports = [
    inputs.noctalia.homeModules.default
  ];

  config = lib.mkIf config.niri.enable {

    home.packages = with pkgs; [
      matugen
      grim
      slurp
      swww
      gpu-screen-recorder
      wl-clipboard
      cliphist
      wlsunset
      ddcutil
      rofi
      eza 
      bat
      tealdeer
      fzf
      nwg-look
      kdePackages.qt6ct
      adw-gtk3
      kitty
    ];

    programs.noctalia-shell = {
      enable = true;
      systemd.enable = true;
      settings = {
        settingsVersion = 31;
        templates = {
          kitty = false;
          niri = true;
          gtk = true;
          qt = true;
          alacritty = true;
          cava = true;
          code = true;
          discord = true;
          emacs = false;
          foot = false;
          fuzzel = false;
          ghostty = false;
          kcolorscheme = false;
          mango = false;
          pywalfox = true;
          spicetify = false;
          telegram = false;
          vicinae = false;
          walker = false;
          wezterm = false;
          yazi = false;
          zed = false;
        };

        colorSchemes = {
          darkMode = true;
          generateTemplatesForPredefined = true;
          manualSunrise = "06:30";
          manualSunset = "18:30";
          matugenSchemeType = "scheme-fidelity";
          predefinedScheme = "Ayu";
          schedulingMode = "off";
          useWallpaperColors = true;
        };

        wallpaper = {
          enabled = true;
          directory = "/home/rupan/media/images/wallpapers";
          panelPosition = "follow_bar";
          randomEnabled = true;
          randomIntervalSec = 3600;
          setWallpaperOnAllMonitors = true;
          transitionDuration = 1500;
          transitionEdgeSmoothness = 0.05;
          transitionType = "fade";
          fillColor = "#000000";
          fillMode = "crop";
          hideWallpaperFilenames = true;
          enableMultiMonitorDirectories = false;
          monitorDirectories = [];
          overviewEnabled = false;
          recursiveSearch = false;
          useWallhaven = false;
          wallhavenCategories = "111";
          wallhavenOrder = "desc";
          wallhavenPurity = "100";
          wallhavenQuery = "";
          wallhavenRatios = "";
          wallhavenResolutionHeight = "";
          wallhavenResolutionMode = "atleast";
          wallhavenResolutionWidth = "";
          wallhavenSorting = "relevance";
        };

        appLauncher = {
          position = "center";
          terminalCommand = "kitty -e";
          customLaunchPrefix = "";
          customLaunchPrefixEnabled = false;
          enableClipPreview = true;
          enableClipboardHistory = false;
          pinnedExecs = [];
          showCategories = true;
          sortByMostUsed = true;
          useApp2Unit = false;
          viewMode = "list";
        };

        bar = {
          position = "top";
          density = "compact";
          exclusive = true;
          floating = false;
          marginHorizontal = 0.25;
          marginVertical = 0.25;
          monitors = [];
          outerCorners = false;
          capsuleOpacity = 1;
          showCapsule = false;
          showOutline = false;
          transparent = true;
          widgets = {
            left = [
              { id = "Workspace"; labelMode = "none"; hideUnoccupied = true; showApplications = false; showLabelsOnlyWhenOccupied = true; enableScrollWheel = true; followFocusedScreen = false; colorizeIcons = false; characterCount = 2; }
              { id = "SystemMonitor"; showCpuTemp = true; showCpuUsage = true; showDiskUsage = true; showMemoryUsage = true; showMemoryAsPercent = true; showGpuTemp = false; showNetworkStats = false; usePrimaryColor = false; diskPath = "/"; }
              { id = "MediaMini"; maxWidth = 145; useFixedWidth = true; showAlbumArt = false; showArtistFirst = true; showProgressRing = false; showVisualizer = true; visualizerType = "linear"; scrollingMode = "hover"; hideMode = "hidden"; hideWhenIdle = false; }
              { id = "WallpaperSelector"; }
              { id = "plugin:launcher-button"; }
              { id = "plugin:catwalk"; }
            ];
            center = [
              { id = "Clock"; formatHorizontal = "ddd MMM d h:mm AP"; formatVertical = "HH mm - dd MM"; useCustomFont = false; customFont = ""; usePrimaryColor = true; }
            ];
            right = [
              { id = "Tray"; drawerEnabled = false; hidePassive = false; colorizeIcons = false; blacklist = []; pinned = []; }
              { id = "NotificationHistory"; showUnreadBadge = true; hideWhenZero = true; }
              { id = "Battery"; displayMode = "alwaysShow"; showNoctaliaPerformance = true; showPowerProfiles = true; warningThreshold = 30; deviceNativePath = ""; }
              { id = "Volume"; displayMode = "alwaysShow"; }
              { id = "Brightness"; displayMode = "alwaysShow"; }
              { id = "ControlCenter"; icon = "noctalia"; useDistroLogo = true; enableColorization = true; colorizeDistroLogo = false; colorizeSystemIcon = "primary"; customIconPath = ""; }
            ];
          };
        };

        ui = {
          fontDefault = "JetBrainsMono Nerd Font";
          fontDefaultScale = 0.95;
          fontFixed = "JetBrainsMono Nerd Font Mono";
          fontFixedScale = 1;
          panelBackgroundOpacity = 0.76;
          panelsAttachedToBar = true;
          settingsPanelMode = "attached";
          tooltipsEnabled = true;
        };

        general = {
          animationDisabled = false;
          animationSpeed = 1;
          avatarImage = "/home/rupan/media/images/pictures/Sponge.jpg";
          boxRadiusRatio = 1;
          compactLockScreen = true;
          dimmerOpacity = 0.2;
          enableShadows = true;
          forceBlackScreenCorners = false;
          iRadiusRatio = 1;
          language = "";
          lockOnSuspend = true;
          radiusRatio = 0.1;
          scaleRatio = 1;
          screenRadiusRatio = 1;
          shadowDirection = "bottom_right";
          shadowOffsetX = 2;
          shadowOffsetY = 3;
          showHibernateOnLockScreen = false;
          showScreenCorners = false;
          showSessionButtonsOnLockScreen = true;
          allowPanelsOnScreenWithoutBar = true;
        };

        audio = {
          cavaFrameRate = 60;
          externalMixer = "pwvucontrol || pavucontrol";
          mprisBlacklist = [];
          preferredPlayer = "spotify";
          visualizerQuality = "high";
          visualizerType = "linear";
          volumeOverdrive = false;
          volumeStep = 5;
        };

        brightness = {
          brightnessStep = 5;
          enableDdcSupport = false;
          enforceMinimum = true;
        };

        calendar = {
          cards = [
            { enabled = true; id = "calendar-header-card"; }
            { enabled = true; id = "calendar-month-card"; }
            { enabled = true; id = "timer-card"; }
            { enabled = true; id = "weather-card"; }
          ];
        };

        controlCenter = {
          position = "close_to_bar_button";
          cards = [
            { enabled = true; id = "profile-card"; }
            { enabled = true; id = "shortcuts-card"; }
            { enabled = true; id = "audio-card"; }
            { enabled = true; id = "brightness-card"; }
            { enabled = true; id = "weather-card"; }
            { enabled = true; id = "media-sysmon-card"; }
          ];
          shortcuts = {
            left = [ { id = "WiFi"; } { id = "Bluetooth"; } { id = "ScreenRecorder"; } { id = "WallpaperSelector"; } ];
            right = [ { id = "Notifications"; } { id = "PowerProfile"; } { id = "KeepAwake"; } { id = "NightLight"; } ];
          };
        };

        desktopWidgets = {
          editMode = false;
          enabled = true;
          gridSnap = true;
          monitorWidgets = [
            { name = "DP-7"; widgets = []; }
            {
              name = "DP-6";
              widgets = [
                { id = "Clock"; x = 740; y = 100; scale = 3; format = "h:mm AP\\nd MMMM yyyy"; clockStyle = "minimal"; showBackground = false; useCustomFont = false; customFont = ""; usePrimaryColor = false; }
                { id = "MediaPlayer"; x = 440; y = 420; scale = 2.834; hideMode = "visible"; showBackground = false; visualizerType = "linear"; visualizerVisibility = "always"; }
                { id = "Weather"; x = 580; y = 780; scale = 3; showBackground = false; }
              ];
            }
          ];
        };

        dock = {
          enabled = false;
          animationSpeed = 1;
          backgroundOpacity = 1;
          colorizeIcons = false;
          deadOpacity = 0.6;
          displayMode = "auto_hide";
          floatingRatio = 1;
          inactiveIndicators = false;
          monitors = [];
          onlySameOutput = true;
          pinnedApps = [];
          pinnedStatic = false;
          size = 1;
        };

        hooks = {
          enabled = false;
          darkModeChange = "";
          performanceModeDisabled = "";
          performanceModeEnabled = "";
          screenLock = "";
          screenUnlock = "";
          wallpaperChange = "";
        };

        location = {
          name = "Chicago";
          analogClockInCalendar = false;
          firstDayOfWeek = -1;
          showCalendarEvents = true;
          showCalendarWeather = true;
          showWeekNumberInCalendar = false;
          use12hourFormat = true;
          useFahrenheit = true;
          weatherEnabled = true;
          weatherShowEffects = true;
        };

        network = { wifiEnabled = true; };

        nightLight = {
          enabled = false;
          autoSchedule = true;
          dayTemp = "6500";
          forced = false;
          manualSunrise = "06:30";
          manualSunset = "18:30";
          nightTemp = "4000";
        };

        notifications = {
          enabled = true;
          location = "top_right";
          backgroundOpacity = 0.7;
          criticalUrgencyDuration = 15;
          enableKeyboardLayoutToast = true;
          lowUrgencyDuration = 3;
          monitors = [];
          normalUrgencyDuration = 8;
          overlayLayer = true;
          respectExpireTimeout = false;
          sounds = {
            enabled = false;
            criticalSoundFile = "";
            excludedApps = "discord,firefox,chrome,chromium,edge";
            lowSoundFile = "";
            normalSoundFile = "";
            separateSounds = false;
            volume = 0.5;
          };
        };

        osd = {
          enabled = true;
          autoHideMs = 2000;
          backgroundOpacity = 1;
          enabledTypes = [ 0 1 2 3 4 ];
          location = "top_right";
          monitors = [];
          overlayLayer = true;
        };

        screenRecorder = {
          directory = "";
          audioCodec = "opus";
          audioSource = "default_output";
          colorRange = "limited";
          frameRate = 60;
          quality = "very_high";
          showCursor = true;
          videoCodec = "h264";
          videoSource = "portal";
        };

        sessionMenu = {
          countdownDuration = 10000;
          enableCountdown = true;
          largeButtonsStyle = false;
          position = "center";
          showHeader = true;
          powerOptions = [
            { action = "lock"; enabled = true; countdownEnabled = true; command = ""; }
            { action = "suspend"; enabled = true; countdownEnabled = true; command = ""; }
            { action = "hibernate"; enabled = true; countdownEnabled = true; command = ""; }
            { action = "reboot"; enabled = true; countdownEnabled = true; command = ""; }
            { action = "logout"; enabled = true; countdownEnabled = true; command = ""; }
            { action = "shutdown"; enabled = true; countdownEnabled = true; command = ""; }
          ];
        };

        systemMonitor = {
          cpuCriticalThreshold = 90; cpuPollingInterval = 3000; cpuWarningThreshold = 80;
          diskCriticalThreshold = 90; diskPollingInterval = 3000; diskWarningThreshold = 80;
          gpuCriticalThreshold = 90; gpuPollingInterval = 3000; gpuWarningThreshold = 80;
          memCriticalThreshold = 95; memPollingInterval = 3000; memWarningThreshold = 80;
          networkPollingInterval = 3000; tempCriticalThreshold = 90; tempPollingInterval = 3000; tempWarningThreshold = 80;
          enableNvidiaGpu = false; useCustomColors = false; warningColor = ""; criticalColor = "";
        };
      };
    };

    ## TERMINAL, SHELL, PROMPT CONFIGURATION
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
       
        set -g fish_color_command ffffff
        set -g fish_color_error ff6666
        set -g fish_color_quote ffffff        
        set -g fish_color_autosuggestion 777777 
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

    systemd.user.services.swww = {
      Unit = {
        Description = "Wayland wallpaper daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.swww}/bin/swww-daemon --no-cache";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
    
    xdg.configFile."niri".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/niri";
    xdg.configFile."kitty".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/kitty";
    xdg.configFile."gtk-2.0".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/gtk-2.0";
    xdg.configFile."gtk-3.0".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/gtk-3.0";
    xdg.configFile."gtk-4.0".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/gtk-4.0";
    xdg.configFile."qt5ct".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/qt5ct";    
    xdg.configFile."qt6ct".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/modules/home-manager/configs/qt6ct";
  };
}
