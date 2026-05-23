{ pkgs, config, ... }:

let
  bg0 = "#141414";
  bg1 = "#202020";
  bg2 = "#323232";
  bg3 = "#5f5f5f";
  fg0 = "#ffffff";
  fg1 = "#f2f2f2";
  fg2 = "#c8c8c8";
  accent = "#ffffff";
  err = "#f0dada";
  glass0 = "rgba(20, 20, 20, 0.42)";
  glass1 = "rgba(255, 255, 255, 0.08)";
  glass2 = "rgba(255, 255, 255, 0.14)";
  glassBorder = "rgba(255, 255, 255, 0.34)";

  rofi = ''
    * {
        font:                        "JetBrainsMono Nerd Font 11";
        background-color:            ${glass0};
        text-color:                  ${fg1};
        border-color:                ${glassBorder};
        selected-normal-background:  ${glass2};
        selected-normal-foreground:  ${fg0};
        normal-background:           transparent;
        normal-foreground:           ${fg1};
    }

    window {
        width:              900px;
        border:             1px solid;
        border-radius:      15px;
        padding:            12px;
        background-color:   ${glass0};
    }

    mainbox { spacing: 0; children: [ inputbar, listview ]; }
    inputbar { padding: 8px 12px; margin: 0 0 10px 0; background-color: ${glass1}; border: 1px solid; border-color: ${glassBorder}; border-radius: 10px; children: [ prompt, entry ]; }
    prompt { padding: 0 8px 0 0; }
    entry { placeholder: "Switch profile..."; placeholder-color: ${fg2}; }
    listview { columns: 3; lines: 2; spacing: 10px; fixed-height: false; scrollbar: false; }
    element { orientation: vertical; padding: 10px; spacing: 8px; border-radius: 10px; background-color: ${glass1}; border: 1px solid; border-color: rgba(255, 255, 255, 0.16); cursor: pointer; }
    element selected { background-color: ${glass2}; border: 1px solid; border-color: ${accent}; }
    element-icon { size: 160px; border-radius: 4px; horizontal-align: 0.5; }
    element-text { horizontal-align: 0.5; vertical-align: 0.5; text-color: inherit; font: "JetBrainsMono Nerd Font 12"; }
  '';
in
{
  desktopProfiles.profiles.clean = {
    bar = "clean";

    cursor = {
      theme = "Bibata-Modern-Ice";
      size = 22;
      package = pkgs.bibata-cursors;
    };

    fonts = {
      ui = {
        family = "JetBrainsMono Nerd Font";
        size = 11;
      };
      mono = {
        family = "Iosevka Nerd Font";
        size = 14;
      };
    };

    appearance = {
      gtkTheme = "adw-gtk3-dark";
      gtkThemeLight = null;
      iconTheme = "Colloid-Dark";
      iconThemeLight = null;
      kittyOpacity = 0.48;
    };

    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/clean";

    makoConfig = ''
      font=JetBrainsMono Nerd Font 11
      background-color=#14141499
      text-color=${fg1}
      border-color=#ffffff66
      border-size=1
      border-radius=6
      width=320
      padding=12
      margin=10
      default-timeout=5000
      icons=1
      max-icon-size=48
      layer=overlay

      [urgency=low]
      border-color=#ffffff44
      default-timeout=3000

      [urgency=high]
      background-color=#202020bb
      border-color=#ffffffaa
      text-color=${fg0}
      default-timeout=0
    '';

    niri = {
      gaps = 12;
      borderOff = true;
      focusRingOff = true;
      shadowSoftness = 30;
      shadowSpread = 4;
      shadowOffsetX = 0;
      shadowOffsetY = 8;
      shadowColor = "#ffffff20";
      shadowInactiveColor = "#00000030";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = true;
      windowOpacity = 0.72;
      windowHighlightOff = true;
      extraConfig = ''
        layer-rule {
            match namespace="^quickshell-clean-topbar$"
            geometry-corner-radius 15
            opacity 0.9
            background-effect {
                blur true
                xray true
                noise 0.015
                saturation 1.25
            }
        }

        layer-rule {
            match namespace="^quickshell-clean-popup$"
            geometry-corner-radius 15
        }

        layer-rule {
            match namespace="^rofi$"
            geometry-corner-radius 15
            opacity 0.88
            background-effect {
                blur true
                xray true
                noise 0.015
                saturation 1.25
            }
        }

        layer-rule {
            match namespace="^mako$"
            geometry-corner-radius 6
            background-effect {
                blur true
                xray true
                noise 0.015
                saturation 1.2
            }
        }

        layer-rule {
            match namespace="^swayosd$"
            geometry-corner-radius 10
            background-effect {
                blur true
                xray true
                noise 0.015
                saturation 1.2
            }
        }
      '';
    };

    colors = {
      gtk3 = ''
        @define-color accent_color ${accent};
        @define-color accent_bg_color rgba(255, 255, 255, 0.24);
        @define-color accent_fg_color ${bg0};
        @define-color destructive_bg_color ${err};
        @define-color destructive_fg_color ${fg0};
        @define-color error_bg_color ${err};
        @define-color error_fg_color ${fg0};
        @define-color window_bg_color rgba(20, 20, 20, 0.54);
        @define-color window_fg_color ${fg1};
        @define-color view_bg_color rgba(20, 20, 20, 0.44);
        @define-color view_fg_color ${fg1};
        @define-color headerbar_bg_color rgba(255, 255, 255, 0.08);
        @define-color headerbar_fg_color ${fg1};
        @define-color popover_bg_color rgba(20, 20, 20, 0.74);
        @define-color popover_fg_color ${fg1};
        @define-color card_bg_color rgba(255, 255, 255, 0.08);
        @define-color card_fg_color ${fg1};
        @define-color sidebar_bg_color rgba(255, 255, 255, 0.06);
        @define-color sidebar_fg_color ${fg1};
        @define-color sidebar_border_color rgba(255, 255, 255, 0.18);
      '';

      gtk4 = ''
        @define-color accent_color ${accent};
        @define-color accent_bg_color rgba(255, 255, 255, 0.24);
        @define-color accent_fg_color ${bg0};
        @define-color destructive_bg_color ${err};
        @define-color destructive_fg_color ${fg0};
        @define-color error_bg_color ${err};
        @define-color error_fg_color ${fg0};
        @define-color window_bg_color rgba(20, 20, 20, 0.54);
        @define-color window_fg_color ${fg1};
        @define-color view_bg_color rgba(20, 20, 20, 0.44);
        @define-color view_fg_color ${fg1};
        @define-color headerbar_bg_color rgba(255, 255, 255, 0.08);
        @define-color headerbar_fg_color ${fg1};
        @define-color popover_bg_color rgba(20, 20, 20, 0.74);
        @define-color popover_fg_color ${fg1};
        @define-color card_bg_color rgba(255, 255, 255, 0.08);
        @define-color card_fg_color ${fg1};
        @define-color sidebar_bg_color rgba(255, 255, 255, 0.06);
        @define-color sidebar_fg_color ${fg1};
        @define-color sidebar_border_color rgba(255, 255, 255, 0.18);
      '';

      qt6 = ''
        [ColorScheme]
        active_colors=${fg1}, ${bg1}, #ffffff, ${bg3}, ${bg2}, ${bg2}, ${fg1}, #ffffff, ${fg1}, ${bg0}, ${bg0}, #000000, ${accent}, ${bg2}, ${accent}, ${fg2}, ${bg1}, ${bg0}, ${bg1}, ${fg1}, ${fg2}, ${accent}
        disabled_colors=${fg2}, ${bg1}, #ffffff, ${bg3}, ${bg2}, ${bg2}, ${fg2}, #ffffff, ${fg2}, ${bg0}, ${bg0}, #000000, ${bg3}, ${bg2}, ${bg3}, ${fg2}, ${bg1}, ${bg0}, ${bg1}, ${fg2}, ${fg2}, ${bg3}
        inactive_colors=${fg2}, ${bg1}, #ffffff, ${bg3}, ${bg2}, ${bg2}, ${fg2}, #ffffff, ${fg2}, ${bg0}, ${bg0}, #000000, ${accent}, ${bg2}, ${accent}, ${fg2}, ${bg1}, ${bg0}, ${bg1}, ${fg2}, ${fg2}, ${accent}
      '';

      kitty = ''
        cursor ${fg1}
        cursor_text_color ${bg0}
        foreground ${fg1}
        background ${bg0}
        selection_foreground ${bg0}
        selection_background ${bg3}
        color0  ${bg1}
        color8  ${bg3}
        color1  ${err}
        color9  ${err}
        color2  ${fg2}
        color10 ${fg1}
        color3  ${fg2}
        color11 ${fg1}
        color4  ${fg2}
        color12 ${fg1}
        color5  ${fg2}
        color13 ${fg1}
        color6  ${fg2}
        color14 ${fg1}
        color7  ${fg1}
        color15 ${fg0}
      '';

      fish = ''
        set -g fish_color_normal ${fg1}
        set -g fish_color_command ${fg0}
        set -g fish_color_keyword ${fg0}
        set -g fish_color_quote ${fg2}
        set -g fish_color_error ${fg0}
        set -g fish_color_param ${fg1}
        set -g fish_color_comment ${fg2}
        set -g fish_color_selection --background=${bg2}
        set -g fish_color_autosuggestion ${fg2}
      '';

      starship = ''
        format = "$all"

        [character]
        success_symbol = "[❯](${fg1})"
        error_symbol = "[❯](${fg0})"

        [directory]
        style = "bold ${fg0}"

        [git_branch]
        style = "bold ${fg2}"

        [cmd_duration]
        style = "bold ${fg2}"
      '';

      rofi = rofi;
    };
  };
}
