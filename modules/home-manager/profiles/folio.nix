{
  pkgs,
  config,
  ...
}:

# Folio (dark only), after seg6/dotfiles: warm paper-on-ink greys, one red signal,
# pixel mono, zero radius, no motion. Runs the vendored folio shell
# (home/configs/quickshell-folio) instead of the repo bar.
let
  static = import ../../../lib/desktop-profiles/static-profile.nix;
  animations = import ../../../lib/desktop-profiles/niri-animations.nix;
  trails = import ../../../lib/desktop-profiles/kitty-cursor-trail.nix;
  motionPresets = import ../../../lib/desktop-profiles/motion.nix;
  inherit (static) alpha;

  palette = {
    title = "Folio";
    bgDim = "#0a0a0b";
    bg0 = "#0d0d0e";
    bg1 = "#1c1b1a";
    bg2 = "#343330";
    bg3 = "#5f5c55";
    fg0 = "#f1ede3";
    fg1 = "#e6e1d5";
    fg2 = "#8b877d";
    fg3 = "#8b877d";
    fg4 = "#5f5c55";
    accent = "#e6e1d5";
    accent2 = "#a39f95";
    red = "#ff4a2b";
    green = "#c9c4b8";
    yellow = "#d9d4c7";
    blue = "#a39f95";
    purple = "#b7b2a6";
    aqua = "#bdb8ac";
    gradLow = "#5f5c55";
    gradMid = "#e6e1d5";
    gradHigh = "#ff4a2b";
  };

  # theme.toml [colors], read by the shell's Theme.qml.
  shellColors = {
    bg = "#0d0d0e";
    bg_alt = "#0a0a0b";
    surface = "#1c1b1a";
    surface_alt = "#343330";
    fg = "#e6e1d5";
    dim = "#8b877d";
    accent = "#e6e1d5";
    red = "#ff4a2b";
    green = "#c9c4b8";
    yellow = "#d9d4c7";
    blue = "#a39f95";
    magenta = "#b7b2a6";
    cyan = "#bdb8ac";
  };

  # Zed theme from their Helix mapping (tools/cli/internal/theme generateHelix).
  zedTheme =
    let
      c = shellColors;
      a = alpha: hex: "${hex}${alpha}";
      fg = {
        color = c.fg;
      };
    in
    {
      "$schema" = "https://zed.dev/schema/themes/v0.2.0.json";
      name = "Folio";
      author = "seg6/dotfiles port";
      themes = [
        {
          name = "Folio";
          appearance = "dark";
          style = {
            border = c.surface_alt;
            "border.variant" = c.surface;
            "border.focused" = c.dim;
            "border.selected" = c.dim;
            "border.transparent" = "#00000000";
            "border.disabled" = c.surface;
            background = c.bg;
            "surface.background" = c.bg_alt;
            "elevated_surface.background" = c.surface;
            "element.background" = c.surface;
            "element.hover" = a "80" c.surface_alt;
            "element.active" = c.surface_alt;
            "element.selected" = c.surface_alt;
            "element.disabled" = c.surface;
            "drop_target.background" = a "40" c.fg;
            "ghost_element.background" = "#00000000";
            "ghost_element.hover" = a "80" c.surface_alt;
            "ghost_element.active" = c.surface_alt;
            "ghost_element.selected" = c.surface_alt;
            "ghost_element.disabled" = "#00000000";
            text = c.fg;
            "text.muted" = c.dim;
            "text.placeholder" = c.dim;
            "text.disabled" = "#5f5c55";
            "text.accent" = c.fg;
            icon = c.fg;
            "icon.muted" = c.dim;
            "icon.disabled" = "#5f5c55";
            "icon.placeholder" = c.dim;
            "icon.accent" = c.fg;
            "status_bar.background" = c.bg;
            "title_bar.background" = c.bg;
            "title_bar.inactive_background" = c.bg;
            "toolbar.background" = c.bg;
            "tab_bar.background" = c.bg;
            "tab.inactive_background" = c.bg;
            "tab.active_background" = c.surface;
            "search.match_background" = a "40" c.red;
            "panel.background" = c.bg;
            "panel.focused_border" = c.dim;
            "pane.focused_border" = c.dim;
            "pane_group.border" = c.surface_alt;
            "scrollbar.thumb.background" = a "40" c.dim;
            "scrollbar.thumb.hover_background" = a "80" c.dim;
            "scrollbar.thumb.border" = "#00000000";
            "scrollbar.track.background" = "#00000000";
            "scrollbar.track.border" = "#00000000";
            "editor.foreground" = c.fg;
            "editor.background" = c.bg;
            "editor.gutter.background" = c.bg;
            "editor.subheader.background" = c.surface;
            "editor.active_line.background" = c.surface;
            "editor.highlighted_line.background" = c.surface;
            "editor.line_number" = "#5f5c55";
            "editor.active_line_number" = c.fg;
            "editor.invisible" = "#5f5c55";
            "editor.wrap_guide" = c.surface;
            "editor.active_wrap_guide" = c.surface_alt;
            "editor.document_highlight.read_background" = a "60" c.surface_alt;
            "editor.document_highlight.write_background" = c.surface_alt;
            "terminal.background" = c.bg;
            "terminal.foreground" = c.fg;
            "terminal.bright_foreground" = "#f1ede3";
            "terminal.dim_foreground" = c.dim;
            "terminal.ansi.black" = c.bg_alt;
            "terminal.ansi.bright_black" = "#5f5c55";
            "terminal.ansi.dim_black" = c.bg_alt;
            "terminal.ansi.red" = c.red;
            "terminal.ansi.bright_red" = "#ff7a62";
            "terminal.ansi.dim_red" = a "99" c.red;
            "terminal.ansi.green" = c.green;
            "terminal.ansi.bright_green" = c.fg;
            "terminal.ansi.dim_green" = a "99" c.green;
            "terminal.ansi.yellow" = c.yellow;
            "terminal.ansi.bright_yellow" = "#f1ede3";
            "terminal.ansi.dim_yellow" = a "99" c.yellow;
            "terminal.ansi.blue" = c.blue;
            "terminal.ansi.bright_blue" = c.green;
            "terminal.ansi.dim_blue" = a "99" c.blue;
            "terminal.ansi.magenta" = c.magenta;
            "terminal.ansi.bright_magenta" = c.yellow;
            "terminal.ansi.dim_magenta" = a "99" c.magenta;
            "terminal.ansi.cyan" = c.cyan;
            "terminal.ansi.bright_cyan" = c.fg;
            "terminal.ansi.dim_cyan" = a "99" c.cyan;
            "terminal.ansi.white" = c.fg;
            "terminal.ansi.bright_white" = "#ffffff";
            "terminal.ansi.dim_white" = c.dim;
            "link_text.hover" = c.fg;
            conflict = c.yellow;
            "conflict.background" = a "1f" c.yellow;
            created = c.green;
            "created.background" = a "1f" c.green;
            deleted = c.red;
            "deleted.background" = a "1f" c.red;
            error = c.red;
            "error.background" = a "1f" c.red;
            hidden = c.dim;
            hint = c.dim;
            ignored = c.dim;
            info = c.cyan;
            "info.background" = a "1f" c.cyan;
            modified = c.yellow;
            "modified.background" = a "1f" c.yellow;
            predictive = c.dim;
            renamed = c.cyan;
            success = c.green;
            unreachable = c.dim;
            warning = c.yellow;
            "warning.background" = a "1f" c.yellow;
            players = [
              {
                cursor = c.red;
                background = c.red;
                selection = a "50" c.surface_alt;
              }
            ];
            syntax = {
              comment = {
                color = c.dim;
                font_style = "italic";
              };
              "comment.doc" = {
                color = c.dim;
                font_style = "italic";
              };
              keyword = {
                color = c.magenta;
              };
              operator = {
                color = c.magenta;
              };
              punctuation = fg;
              string = {
                color = c.green;
              };
              "string.escape" = {
                color = c.magenta;
              };
              "string.regex" = {
                color = c.magenta;
              };
              number = {
                color = c.red;
              };
              boolean = fg;
              constant = fg;
              type = {
                color = c.cyan;
              };
              function = fg;
              constructor = fg;
              variable = fg;
              "variable.special" = {
                color = c.cyan;
              };
              property = fg;
              attribute = {
                color = c.cyan;
              };
              tag = {
                color = c.magenta;
              };
              label = fg;
              title = {
                color = c.fg;
                font_weight = 700;
              };
              emphasis = {
                color = c.fg;
                font_style = "italic";
              };
              "emphasis.strong" = {
                color = c.fg;
                font_weight = 700;
              };
              link_uri = {
                color = c.cyan;
              };
              link_text = {
                color = c.magenta;
              };
              "text.literal" = {
                color = c.green;
              };
              hint = {
                color = c.dim;
                font_style = "italic";
              };
              predictive = {
                color = c.dim;
                font_style = "italic";
              };
            };
          };
        }
      ];
    };

  # sway's $line: fg blended 32% toward bg in Lab.
  line = "#99968f";

  overrides = {
    kitty = r: {
      selectionForeground = r.fg1;
      selectionBackground = r.bg2;
      color0 = r.bgDim;
      color8 = r.bg3;
      color9 = "#ff7a62";
      color10 = r.fg1;
      color11 = r.fg0;
      color12 = r.green;
      color13 = r.yellow;
      color14 = r.fg1;
      color7 = r.fg1;
      color15 = "#ffffff";
    };
    fish = r: {
      command = r.fg0;
      keyword = r.fg0;
      param = r.fg1;
      quote = r.fg2;
      redirection = r.fg2;
      operator = r.fg1;
      escape = r.fg2;
    };
    starship = r: {
      success = r.fg1;
      directory = r.fg0;
      gitBranch = r.fg2;
    };
  };
in
{
  home.packages = [
    pkgs.departure-mono
    pkgs.nerd-fonts.fantasque-sans-mono
    (pkgs.google-fonts.override { fonts = [ "Newsreader" ]; })
    pkgs.seg6-ws
  ];

  # The launcher's "Resume" rows are ws's recent projects (~/.local/state/ws).
  xdg.configFile."ws/config.toml".source = (pkgs.formats.toml { }).generate "ws-config.toml" {
    workspace = {
      root = "~/projects";
      max_depth = 3;
      ignore = [
        "node_modules"
        "target"
        "vendor"
        ".venv"
        "result"
      ];
    };
    session.windows = [
      {
        index = 1;
        name = "editor";
        command = "nvim .";
      }
      {
        index = 9;
        name = "files";
        command = "yazi";
      }
    ];
  };

  xdg.configFile."folio/colors.json".text = builtins.toJSON shellColors;
  xdg.configFile."zed/themes/folio.json".text = builtins.toJSON zedTheme;
  xdg.configFile."folio/who.json".text = builtins.toJSON {
    city = "Madison";
    place = "Madison";
    latitude = "43.07";
    longitude = "-89.40";
    # Live place/coordinates from Home Assistant (the phone's GPS; the laptop has none).
    tracker = "device_tracker.rupan_phone";
    geocoded = "sensor.rupan_phone_geocoded_location";
  };

  desktopProfiles.profiles.folio = static.mkStaticProfile {
    inherit palette overrides;
    bar = "folio";
    wallpaperDir = "${config.assetsPath}/wallpapers/folio";

    quickshell = r: {
      fg = r.fg1;
      bg = alpha "ee" r.bg0;
      popupBg = alpha "ee" r.bg0;
      accent = r.red;
      second = r.fg2;
      warm = r.red;
      fresh = r.fg1;
      barFont = "Departure Mono";
      barRadius = "0";
      barHeight = "26";
      barMargin = "0";
      barMarginTop = "0";
      flatMode = "true";
      showClockDate = "false";
      showWorkspaceNumbers = "true";
      showBarDividers = "false";
      barBorder = "#00000000";
      barInnerHighlight = "#00000000";
      pillBg = "#00000000";
      pillBorder = "#00000000";
      moduleAnimationStyle = "fade";
      popupAttachToBar = "true";
      popupAnimationStyle = "attachedSlide";
    };

    cursor = {
      theme = "Adwaita";
      size = 24;
      package = pkgs.adwaita-icon-theme;
    };

    fonts = {
      ui = {
        family = "Newsreader";
        size = 12;
      };
      mono = {
        family = "FantasqueSansM Nerd Font";
        size = 16;
      };
    };

    appearance = {
      gtkTheme = "adw-gtk3-dark";
      gtkThemeLight = null;
      iconTheme = "Papirus-Dark";
      iconThemeLight = "Papirus-Dark";
      kittyCursorTrail = trails.snappy // {
        delayMs = 0;
        blinkInterval = "0";
      };
      motion = motionPresets.snappy;
      # seg6/dotfiles kitty: roomy padding, borderless text tab bar on top.
      kittyExtraConfig = ''

        window_padding_width 18 20 10 20
        hide_window_decorations yes
        cursor_shape block
        cursor_shape_unfocused hollow
        tab_bar_style separator
        tab_separator "   "
        tab_bar_min_tabs 2
        tab_bar_edge top
        tab_bar_align left
        tab_bar_margin_width 20
        tab_bar_margin_height 12 2
        tab_bar_background none
        tab_bar_margin_color none
        active_tab_font_style normal
        inactive_tab_font_style normal
        active_tab_foreground #e6e1d5
        active_tab_background #0d0d0e
        inactive_tab_foreground #5f5c55
        inactive_tab_background #0d0d0e
      '';
    };

    niri = {
      animations = animations.snappy;
      animationsOff = true;
      gaps = 12;
      layoutExtraConfig = ''
        struts {
            left 24
            right 24
        }
      '';
      borderOff = false;
      borderWidth = 1;
      borderActiveColor = line;
      borderInactiveColor = palette.bg2;
      focusRingOff = true;
      shadowOff = true;
      shadowSoftness = 0;
      shadowSpread = 0;
      shadowOffsetX = 0;
      shadowOffsetY = 0;
      shadowColor = "#00000000";
      shadowInactiveColor = "#00000000";
      shadowDrawBehindWindow = false;
      tabIndicatorOff = true;
      windowOpacity = 1.0;
      windowHighlightOff = true;
      extraConfig = ''
        window-rule {
            geometry-corner-radius 0
            clip-to-geometry true
        }

        // swayfx default_dim_inactive 0.22 over the near-black page.
        window-rule {
            match is-focused=false
            opacity 0.78
        }

        layer-rule {
            match namespace="^folio"
            geometry-corner-radius 0
        }

        // Paper behind workspace switches and the overview, where awww-daemon
        // sits for the other profiles. Backdrop layers get no input, so only
        // this inert fill goes there; the interactive page stays on top.
        layer-rule {
            match namespace="^folio-backdrop$"
            place-within-backdrop true
        }

        binds {
            Mod+Grave hotkey-overlay-title="Folio: next desktop view" { spawn "folio-menu" "view" "next"; }
            Mod+Shift+Grave { spawn "folio-menu" "view" "prev"; }
            Mod+Slash hotkey-overlay-title="Folio: key sheet" { spawn "folio-menu" "keys"; }
            Mod+Shift+Return hotkey-overlay-title="Folio: project picker (ws)" { spawn "kitty" "ws"; }
        }
      '';
    };
  };
}
