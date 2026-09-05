{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.programs.noctalia;
  kittyAgentColorsHook = pkgs.writeShellScript "kitty-agent-colors-reload" ''
    ${pkgs.python3}/bin/python3 ${config.repoPath}/home/scripts/sync-kitty-agent-colors \
      ${config.home.homeDirectory}/.config/kitty >/dev/null 2>&1 || true
    ${pkgs.procps}/bin/pkill -USR1 kitty || true
  '';
  # noctalia templates expose `.hex`; DownToneUI needs "r, g, b" for alpha overlays.
  firefoxGlobalsHook = pkgs.writeShellScript "firefox-globals-reload" ''
    ${config.repoPath}/home/scripts/firefox-globals >/dev/null 2>&1 || true
  '';
in
{
  options.noctalia.enable = lib.mkEnableOption "enable noctalia";

  imports = [ inputs.noctalia.homeModules.default ];

  config = lib.mkIf config.noctalia.enable {
    home.packages = with pkgs; [
      gpu-screen-recorder
      cliphist
      wlsunset
      ddcutil
      python3
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

    xdg.configFile."noctalia/templates/firefox-palette".text = ''
      surface={{colors.surface.default.hex}}
      on_surface={{colors.on_surface.default.hex}}
      primary={{colors.primary.default.hex}}
    '';

    xdg.configFile."noctalia/templates/starship.toml".text = ''
      scan_timeout = 100
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

    programs.noctalia = {
      enable = true;
      systemd.enable = false;
      # v5 schema (noctalia 5.0.0): snake_case throughout. Old camelCase keys
      # are dropped by the validator, so every block below was re-mapped from
      # the pre-5.0 config. Dropped with no v5 equivalent: general.dimmerOpacity,
      # allowPanelsOnScreenWithoutBar, compactLockScreen, tooltips, font scaling,
      # bar density/margins/transparency/outline, OSD durations, notification
      # durations/sounds, sessionMenu hibernate + header, brightness/volume steps,
      # audio mixer/visualizer/player prefs, wallpaper wallhaven/multi-monitor
      # knobs, template toggles folded into builtin_ids/community_ids.
      settings = {
        shell = {
          font_family = "JetBrainsMono Nerd Font";
          avatar_path = "${config.repoPath}/home/assets/Sponge.jpg";
          clipboard_enabled = false;
          show_location = true;
          animation = {
            enabled = true;
            speed = 1;
          };
          shadow = {
            direction = "down_right";
          };
          panel = {
            launcher_placement = "attached";
            clipboard_placement = "attached";
          };
          launcher = {
            categories = true;
            sort_by_usage = true;
          };
          mpris = {
            blacklist = [ ];
          };
          session = {
            grid = false;
            actions = [
              {
                action = "lock";
                countdown_seconds = 10;
              }
              {
                action = "suspend";
                countdown_seconds = 10;
              }
              {
                action = "reboot";
                countdown_seconds = 10;
              }
              {
                action = "logout";
                countdown_seconds = 10;
              }
              {
                action = "shutdown";
                variant = "destructive";
                countdown_seconds = 10;
              }
            ];
          };
        };

        lockscreen = {
          enabled = true;
          lock_before_suspend = true;
        };

        theme = {
          mode = "dark";
          source = "wallpaper";
          builtin = "Noctalia";
          wallpaper_scheme = "m3-tonal-spot";
          templates = {
            enable_builtin_templates = true;
            builtin_ids = [
              "niri"
              "gtk3"
              "gtk4"
              "qt"
              "alacritty"
              "cava"
            ];
            enable_community_templates = true;
            community_ids = [
              "vscode"
              "discord"
            ];
            user = {
              kitty = {
                input_path = "~/.config/noctalia/templates/kitty.conf";
                output_path = "~/.config/kitty/colors.conf";
                post_hook = "${kittyAgentColorsHook}";
              };
              fish = {
                input_path = "~/.config/noctalia/templates/fish.fish";
                output_path = "~/.config/fish/conf.d/matugen_theme.fish";
              };
              starship = {
                input_path = "~/.config/noctalia/templates/starship.toml";
                output_path = "~/.config/starship_matugen.toml";
              };
              firefox = {
                input_path = "~/.config/noctalia/templates/firefox-palette";
                output_path = "~/.config/desktop-profiles/runtime-firefox-palette";
                post_hook = "${firefoxGlobalsHook}";
              };
            };
          };
        };

        wallpaper = {
          enabled = true;
          directory = "${config.assetsPath}/wallpapers/noctalia";
          fill_mode = "crop";
          fill_color = "#000000";
          transition = [ "fade" ];
          transition_duration = 1500;
          edge_smoothness = 0.05;
          automation = {
            enabled = true;
            interval_seconds = 3600;
            order = "random";
            recursive = false;
          };
        };

        bar.main = {
          position = "top";
          reserve_space = true;
          start = [
            "workspaces"
            "sysmon_cpu"
            "sysmon_cpu_temp"
            "sysmon_mem"
            "sysmon_disk"
            "media"
            "wallpaper"
            "launcher"
          ];
          center = [ "clock" ];
          end = [
            "tray"
            "network"
            "notifications"
            "battery"
            "volume"
            "brightness"
            "control-center"
          ];
        };

        widget = {
          workspaces = {
            show_labels = true;
            labels_only_when_occupied = true;
            hide_when_empty = true;
            max_label_chars = 2;
          };
          sysmon_cpu = {
            type = "sysmon";
            stat = "cpu_usage";
          };
          sysmon_cpu_temp = {
            type = "sysmon";
            stat = "cpu_temp";
          };
          sysmon_mem = {
            type = "sysmon";
            stat = "ram_pct";
          };
          sysmon_disk = {
            type = "sysmon";
            stat = "disk_used_pct";
            path = "/";
          };
          media = {
            min_length = 145;
            max_length = 145;
            hide_album_art = true;
            artist_first = true;
            title_scroll = "on_hover";
            hide_when_no_media = false;
          };
          clock = {
            format = "{:%a %b %-d %-I:%M %p}";
            vertical_format = "{:%H:%M}";
          };
          tray = {
            drawer = false;
            hide_passive = false;
            hidden = [ "nm-applet" ];
            pinned = [ ];
          };
          notifications = {
            hide_when_no_unread = true;
          };
        };

        control_center = {
          shortcuts = [
            { type = "wifi"; }
            { type = "bluetooth"; }
            { type = "screen_recorder"; }
            { type = "wallpaper"; }
            { type = "notification"; }
            { type = "power_profile"; }
            { type = "caffeine"; }
            { type = "nightlight"; }
          ];
          calendar = {
            show_events_card = true;
            show_week_numbers = false;
          };
        };

        plugins = {
          # Screen recorder moved to an official plugin in v5; the shortcut
          # above stays disabled until it loads (needs network on first run).
          enabled = [ "noctalia/screen_recorder" ];
        };

        desktop_widgets = {
          enabled = true;
        };

        dock = {
          enabled = false;
        };

        nightlight = {
          enabled = false;
          temperature_day = 6500;
          temperature_night = 4000;
        };

        notification = {
          enable_daemon = true;
          background_opacity = 0.7;
        };

        osd = {
          position = "top_right";
          background_opacity = 1.0;
          kinds = {
            keyboard_layout = true;
          };
        };

        battery = {
          warning_threshold = 30;
        };

        system.monitor = {
          cpu_poll_seconds = 3.0;
          memory_poll_seconds = 3.0;
          network_poll_seconds = 3.0;
          disk_poll_seconds = 3.0;
        };
      };
    };

    # Own the user service so rebuilds keep working; package/config stay upstream.
    systemd.user.services.noctalia-shell = {
      Unit = {
        Description = "Noctalia Shell - Wayland desktop shell";
        Documentation = "https://docs.noctalia.dev";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
        X-Restart-Triggers =
          lib.optional (cfg.settings != { }) "${config.xdg.configFile."noctalia/config.toml".source}"
          ++ lib.mapAttrsToList (
            name: _: "${config.xdg.configFile."noctalia/palettes/${name}.json".source}"
          ) cfg.customPalettes;
      };
      Service = {
        # Skip (not fail) when another profile is active.
        ExecCondition = "${pkgs.bash}/bin/bash -c '[ \"$(cat %h/.config/desktop-profiles/active 2>/dev/null || echo noctalia)\" = \"noctalia\" ]'";
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ config.wayland.systemd.target ];
      };
    };
  };
}
