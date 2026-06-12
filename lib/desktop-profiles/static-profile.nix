# Default role mapping for static desktop profiles.
#
# A profile built with mkStaticProfile is mostly just a palette: the canonical
# roles below feed default mappings for every theme slot (gtk, qt6, kitty,
# fish, starship, rofi, btop, tmux, hyprlock, cava, mako, quickshell,
# waybar). Anything a
# theme does differently goes in `overrides.<slot>` (an attrset of builder
# args, or a function `palette: attrset` for per-variant values).
#
# Canonical palette roles (only bg0, bg1, bg2, fg1 and accent are required;
# everything else cascades):
#   bg0..bg3   surfaces, increasing elevation   bgDim   darker-than-bg0 tone
#   fg0..fg4   strong text → faint text         comment muted comment tone
#   accent, accent2                             gray    disabled secondary
#   red orange yellow green aqua blue purple    grad{Low,Mid,High}
#   onAccent / onError  ink tones on accent/error backgrounds
#   title, barBg (rgba), barShadow (rgba), plus any extra keys overrides need
let
  theme = import ./theme-builders.nix;
  waybar = import ../waybar.nix;

  alpha = a: c: "#${a}${builtins.substring 1 6 c}";

  applyOv = ov: r: if builtins.isFunction ov then ov r else ov;

  resolve =
    p:
    rec {
      inherit (p)
        bg0
        bg1
        bg2
        fg1
        accent
        ;
      bg3 = p.bg3 or bg2;
      bgDim = p.bgDim or bg0;
      fg0 = p.fg0 or fg1;
      fg2 = p.fg2 or fg1;
      fg3 = p.fg3 or fg2;
      fg4 = p.fg4 or fg3;
      accent2 = p.accent2 or accent;
      red = p.red or accent;
      yellow = p.yellow or accent;
      orange = p.orange or yellow;
      green = p.green or accent;
      aqua = p.aqua or green;
      blue = p.blue or accent;
      purple = p.purple or accent;
      gray = p.gray or fg4;
      comment = p.comment or fg4;
      onAccent = p.onAccent or bg0;
      onError = p.onError or fg0;
      gradLow = p.gradLow or green;
      gradMid = p.gradMid or yellow;
      gradHigh = p.gradHigh or red;
      title = p.title or "";
      barBg = p.barBg or "rgba(0, 0, 0, 0.6)";
      barShadow = p.barShadow or "rgba(0, 0, 0, 0.45)";
    }
    // p;

  mkColorsFor =
    r: overrides:
    let
      ov = slot: applyOv (overrides.${slot} or { }) r;
    in
    theme.mkGtkPair (
      {
        inherit (r) title accent;
        accentFg = r.onAccent;
        destructiveBg = r.red;
        destructiveFg = r.onError;
        windowBg = r.bg0;
        windowFg = r.fg1;
        headerbarBg = r.bg1;
        headerbarBackdrop = "@window_bg_color";
        popoverBg = r.bg1;
        cardBg = r.bg1;
        dialogBg = r.bg0;
        dialogFg = r.fg1;
        sidebarBg = r.bg1;
        sidebarBackdrop = "@window_bg_color";
        sidebarBorder = r.bg2;
        secondarySidebarBg = r.bg0;
        secondarySidebarFg = r.fg2;
        unfocused = {
          fg = r.fg3;
          text = r.fg4;
          bg = r.bg0;
          base = r.bg0;
          selectedBg = r.bg2;
          selectedFg = r.fg1;
        };
      }
      // ov "gtk"
    )
    // {
      qt6 = theme.mkQt6Roles (
        {
          windowText = r.fg1;
          button = r.bg1;
          midlight = r.bg3;
          mid = r.bg2;
          window = r.bg0;
          highlight = r.accent;
          highlightedText = r.bg0;
          linkVisited = r.blue;
          alternateBase = r.bg1;
          tooltipBase = r.bgDim;
          tooltipText = r.bg1;
          secondaryText = r.fg4;
          inactiveText = r.fg2;
          disabledText = r.fg4;
          disabledHighlight = r.bg3;
          disabledHighlightedText = r.bg2;
          disabledSecondaryText = r.gray;
        }
        // ov "qt6"
      );

      kitty = theme.mkKittyColors (
        {
          title = if r.title == "" then null else "${r.title} Kitty";
          cursor = r.fg1;
          cursorText = r.bg0;
          foreground = r.fg1;
          background = r.bg0;
          selectionForeground = r.bg0;
          selectionBackground = r.accent;
          color0 = r.bg1;
          color8 = r.bg3;
          color1 = r.red;
          color9 = r.red;
          color2 = r.green;
          color10 = r.green;
          color3 = r.yellow;
          color11 = r.yellow;
          color4 = r.blue;
          color12 = r.blue;
          color5 = r.purple;
          color13 = r.purple;
          color6 = r.aqua;
          color14 = r.aqua;
          color7 = r.fg4;
          color15 = r.fg1;
        }
        // ov "kitty"
      );

      fish = theme.mkFishColors (
        {
          normal = r.fg1;
          command = r.accent;
          keyword = r.accent2;
          quote = r.green;
          redirection = r.aqua;
          end = r.fg4;
          error = r.red;
          param = r.fg2;
          inherit (r) comment;
          selection = r.bg2;
          searchMatch = r.bg1;
          operator = r.accent2;
          escape = r.purple;
          autosuggestion = r.comment;
        }
        // ov "fish"
      );

      starship = theme.mkStarshipPrompt (
        {
          success = r.accent;
          error = r.red;
          directory = r.blue;
          gitBranch = r.accent2;
          cmdDuration = r.fg4;
        }
        // ov "starship"
      );

      rofi = theme.mkProfilePickerRofi (
        {
          background = r.bg0;
          text = r.fg1;
          border = r.bg2;
          selectedBackground = r.bg1;
          selectedForeground = r.accent;
          inputBackground = r.bg1;
          prompt = r.accent;
          placeholder = r.bg3;
          elementBackground = r.bg1;
          elementSelectedBackground = r.bg2;
          elementSelectedBorder = r.accent;
        }
        // ov "rofi"
      );

      btop = theme.mkBtopTheme (
        {
          mainBg = r.bg0;
          mainFg = r.fg1;
          hiFg = r.accent;
          selectedBg = r.bg2;
          inactiveFg = r.fg4;
          procMisc = r.green;
          box = r.bg2;
          inherit (r) gradLow gradMid gradHigh;
        }
        // ov "btop"
      );

      tmux = theme.mkTmuxColors (
        {
          bg = r.bg1;
          fg = r.fg1;
          inherit (r) accent;
          secondary = r.fg2;
          inactive = r.fg4;
          border = r.bg2;
        }
        // ov "tmux"
      );

      hyprlock = theme.mkHyprlockColors (
        {
          fg = r.fg0;
          muted = r.fg3;
          inherit (r) accent;
          surface = r.bgDim;
          surfaceAlt = r.bg1;
          error = r.red;
        }
        // ov "hyprlock"
      );

      cava = theme.mkCavaColors ({ inherit (r) gradLow gradMid gradHigh; } // ov "cava");
    };

  mkStaticProfile =
    {
      palette,
      scriptDir,
      wallpaperDir,
      paletteLight ? null,
      wallpaperDirLight ? null,
      bar ? "quickshell",
      cursor ? { },
      fonts ? { },
      appearance ? { },
      niri ? { },
      quickshell ? { },
      waybarStyle ? "floating", # "floating" | "pill" | "flat"
      waybarConfig ? { },
      overrides ? { },
      runtime ? { },
    }:
    let
      d = resolve palette;
      l = if paletteLight == null then null else resolve paletteLight;

      monoFont = (fonts.mono or { }).family or "JetBrainsMono Nerd Font";

      mkQs =
        r:
        {
          fg = r.fg1;
          bg = alpha "66" r.bg0;
          popupBg = alpha "cc" r.bg0;
          rawBg = r.bg0;
          inherit (r) accent;
          second = r.fg2;
          warm = r.orange;
          fresh = r.green;
          barRadius = "10";
          barHeight = "32";
          showClockDate = "false";
          showWorkspaceNumbers = "false";
          barFont = monoFont;
          barBorder = "#00000000";
          pillBorder = alpha "1d" r.bg1;
        }
        // applyOv quickshell r;

      mkMakoFor =
        r:
        theme.mkMakoConfig (
          {
            background = r.bg0;
            text = r.fg1;
            border = r.accent;
            lowBorder = r.bg3;
            highBackground = r.bg1;
            highBorder = r.red;
            highText = r.fg0;
          }
          // applyOv (overrides.mako or { }) r
        );

      waybarStyleFn =
        {
          floating = waybar.mkFloatingStyle;
          pill = waybar.mkPillStyle;
          flat = waybar.mkFlatStyle;
        }
        .${waybarStyle};

      waybarArgsFor =
        r:
        (
          if waybarStyle == "flat" then
            {
              fg = r.fg1;
              activeText = r.fg0;
              activeUnderline = r.accent;
              clockColor = r.fg1;
              performanceColor = r.red;
              balancedColor = r.accent;
              powerSaverColor = r.green;
              warningColor = r.yellow;
              criticalColor = r.red;
            }
          else
            {
              windowBg = r.barBg;
              primary = r.accent;
              borderColor = r.bg2;
              shadowColor = r.barShadow;
              activeBg = r.bg2;
              hoverColor = r.orange;
              clockColor = r.accent;
              textColor = r.fg1;
              performanceColor = r.red;
              balancedColor = r.accent;
              powerSaverColor = r.green;
              warningColor = r.yellow;
              criticalColor = r.red;
            }
        )
        // applyOv (overrides.waybarStyle or { }) r;
    in
    {
      inherit
        bar
        cursor
        fonts
        appearance
        wallpaperDir
        wallpaperDirLight
        runtime
        ;

      niri = {
        tabIndicatorActiveColor = d.accent;
        tabIndicatorInactiveColor = d.bg2;
        borderActiveColor = d.accent;
        borderInactiveColor = d.bg1;
        focusRingActiveColor = d.accent;
        focusRingInactiveColor = d.bg1;
        urgentColor = d.red;
      }
      // niri;

      quickshellTheme = mkQs d;
      makoConfig = mkMakoFor d;
      colors = mkColorsFor d overrides;

      waybar = {
        config = waybar.mkConfig (
          {
            inherit scriptDir;
            floating = waybarStyle != "flat";
            pill = waybarStyle == "pill";
          }
          // waybarConfig
        );
        style = waybarStyleFn (waybarArgsFor d);
      };
    }
    // (
      if l == null then
        { }
      else
        {
          quickshellThemeLight = mkQs l;
          makoConfigLight = mkMakoFor l;
          colorsLight = mkColorsFor l overrides;
          waybarLight.style = waybarStyleFn (waybarArgsFor l);
        }
    );
in
{
  inherit
    mkStaticProfile
    mkColorsFor
    resolve
    alpha
    ;
}
