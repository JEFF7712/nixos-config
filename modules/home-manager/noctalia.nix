{ inputs, pkgs, lib, config, ... }: {

  options = {
    noctalia.enable = lib.mkEnableOption "enable noctalia"; 
  };

  imports = [
    inputs.noctalia.homeModules.default
  ];

  config = lib.mkIf config.noctalia.enable {

    home.packages = with pkgs; [
      matugen
      gpu-screen-recorder
      cliphist
      wlsunset
      ddcutil
      nwg-look
      kdePackages.qt6ct
      adw-gtk3
      kitty
    ];
    
    xdg.configFile."noctalia/templates/kitty.conf".text = ''
        # Cursor
        cursor {{colors.on_surface.default.hex}}
        cursor_text_color {{colors.surface.default.hex}}

        # Main
        foreground {{colors.on_surface.default.hex}}
        background {{colors.surface.default.hex}}
        selection_foreground {{colors.on_primary.default.hex}}
        selection_background {{colors.primary.default.hex}}

        # Black
        color0 {{colors.surface_container_low.default.hex}}
        color8 {{colors.surface_container_high.default.hex}}

        # Red (Error colors are usually preserved even in monochrome for functionality)
        color1 {{colors.error.default.hex}}
        color9 {{colors.error_container.default.hex}}

        # Green -> Primary
        color2 {{colors.primary.default.hex}}
        color10 {{colors.primary_container.default.hex}}

        # Yellow -> Secondary
        color3 {{colors.secondary.default.hex}}
        color11 {{colors.secondary_container.default.hex}}

        # Blue -> Tertiary
        color4 {{colors.tertiary.default.hex}}
        color12 {{colors.tertiary_container.default.hex}}

        # Magenta -> Primary
        color5 {{colors.primary.default.hex}}
        color13 {{colors.primary_container.default.hex}}

        # Cyan -> Secondary
        color6 {{colors.secondary.default.hex}}
        color14 {{colors.secondary_container.default.hex}}

        # White
        color7 {{colors.on_surface.default.hex}}
        color15 {{colors.on_surface_variant.default.hex}}
    '';

    xdg.configFile."noctalia/templates/fish.fish".text = ''
      set -g fish_color_normal {{colors.on_surface.default.hex}}
      set -g fish_color_command {{colors.primary.default.hex}}
      set -g fish_color_keyword {{colors.tertiary.default.hex}}
      set -g fish_color_quote {{colors.secondary.default.hex}}
      set -g fish_color_redirection {{colors.on_surface.default.hex}}
      set -g fish_color_end {{colors.on_surface_variant.default.hex}}
      set -g fish_color_error {{colors.error.default.hex}}
      set -g fish_color_param {{colors.on_surface.default.hex}}
      set -g fish_color_comment {{colors.outline.default.hex}}
      set -g fish_color_selection --background={{colors.surface_container_highest.default.hex}}
      set -g fish_color_search_match --background={{colors.surface_container_highest.default.hex}}
      set -g fish_color_operator {{colors.primary.default.hex}}
      set -g fish_color_escape {{colors.secondary.default.hex}}
      set -g fish_color_autosuggestion {{colors.on_surface_variant.default.hex}}
    '';

    xdg.configFile."noctalia/templates/starship.toml".text = ''
      format = "$all"
      
      [character]
      success_symbol = "[❯]({{colors.primary.default.hex}})"
      error_symbol = "[❯]({{colors.error.default.hex}})"

      [directory]
      style = "bold {{colors.secondary.default.hex}}"

      [git_branch]
      style = "bold {{colors.tertiary.default.hex}}"

      [cmd_duration]
      style = "bold {{colors.on_surface_variant.default.hex}}"
    '';

    programs.noctalia-shell = {
      enable = true;
      systemd.enable = true;
      user-templates = {
        config = {
          scheme_type = "scheme_tonal-spot"; 
        };
        
        templates = {
          kitty = {
            input_path = "~/.config/noctalia/templates/kitty.conf";
            output_path = "~/.config/kitty/colors.conf";
            post_hook = "${pkgs.procps}/bin/pkill -USR1 kitty";
          };
          fish = {
            input_path = "~/.config/noctalia/templates/fish.fish";
            output_path = "~/.config/fish/conf.d/matugen_theme.fish";
          };
          starship = {
            input_path = "~/.config/noctalia/templates/starship.toml";
            output_path = "~/.config/starship_matugen.toml";
          };
        };
      };
      settings = {
        settingsVersion = 31;
        templates = {
          enableUserTemplates = true;
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
          matugenSchemeType = "scheme-tonal-spot";
          predefinedScheme = "Ayu";
          schedulingMode = "off";
          useWallpaperColors = true;
        };

        wallpaper = {
          enabled = true;
          directory = "/home/rupan/nixos/modules/home-manager/assets/wallpapers";
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
          avatarImage = "/home/rupan/nixos/modules/home-manager/assets/Sponge.jpg";
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
  };
}