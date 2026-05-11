{ pkgs, config, ... }:

let
  bg0 = "#2a2a2a";
  bg1 = "#343434";
  bg2 = "#444444";
  bg3 = "#5a5a5a";
  fg0 = "#f6f6f6";
  fg1 = "#e0e0e0";
  fg2 = "#b4b4b4";
  accent = "#f0f0f0";
  err = "#8a8a8a";

  rofi = ''
    * {
        font:                        "JetBrainsMono Nerd Font 11";
        background-color:            ${bg0};
        text-color:                  ${fg1};
        border-color:                ${bg3};
        selected-normal-background:  ${bg1};
        selected-normal-foreground:  ${fg0};
        normal-background:           ${bg0};
        normal-foreground:           ${fg1};
    }

    window {
        width:              900px;
        border:             1px solid;
        border-radius:      6px;
        padding:            12px;
        background-color:   ${bg0};
    }

    mainbox { spacing: 0; children: [ inputbar, listview ]; }
    inputbar { padding: 8px 12px; margin: 0 0 10px 0; background-color: ${bg1}; border-radius: 6px; children: [ prompt, entry ]; }
    prompt { padding: 0 8px 0 0; }
    entry { placeholder: "Switch profile..."; placeholder-color: ${fg2}; }
    listview { columns: 3; lines: 2; spacing: 10px; fixed-height: false; scrollbar: false; }
    element { orientation: vertical; padding: 10px; spacing: 8px; border-radius: 6px; background-color: ${bg1}; cursor: pointer; }
    element selected { background-color: ${bg2}; border: 1px solid; border-color: ${accent}; }
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
        family = "Inter";
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
    };

    wallpaperDir = "${config.repoPath}/home/assets/wallpapers/clean";

    makoConfig = ''
      font=JetBrainsMono Nerd Font 11
      background-color=${bg0}
      text-color=${fg1}
      border-color=${bg3}
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
      border-color=${bg2}
      default-timeout=3000

      [urgency=high]
      background-color=${bg1}
      border-color=${err}
      text-color=${fg0}
      default-timeout=0
    '';

    niri = {
      gaps = 4;
      borderOff = true;
      focusRingOff = true;
      shadowSoftness = 1;
      shadowSpread = 0;
      shadowOffsetX = 0;
      shadowOffsetY = 0;
      shadowColor = "#00000000";
      shadowInactiveColor = "#00000000";
      shadowDrawBehindWindow = true;
      tabIndicatorOff = true;
      windowOpacity = 1.0;
      windowHighlightOff = true;
    };

    colors = {
      gtk3 = ''
        @define-color accent_color ${accent};
        @define-color accent_bg_color ${bg3};
        @define-color accent_fg_color ${bg0};
        @define-color destructive_bg_color ${err};
        @define-color destructive_fg_color ${fg0};
        @define-color error_bg_color ${err};
        @define-color error_fg_color ${fg0};
        @define-color window_bg_color ${bg0};
        @define-color window_fg_color ${fg1};
        @define-color view_bg_color ${bg0};
        @define-color view_fg_color ${fg1};
        @define-color headerbar_bg_color ${bg1};
        @define-color headerbar_fg_color ${fg1};
        @define-color popover_bg_color ${bg1};
        @define-color popover_fg_color ${fg1};
        @define-color card_bg_color ${bg1};
        @define-color card_fg_color ${fg1};
        @define-color sidebar_bg_color ${bg1};
        @define-color sidebar_fg_color ${fg1};
        @define-color sidebar_border_color ${bg2};
      '';

      gtk4 = ''
        @define-color accent_color ${accent};
        @define-color accent_bg_color ${bg3};
        @define-color accent_fg_color ${bg0};
        @define-color destructive_bg_color ${err};
        @define-color destructive_fg_color ${fg0};
        @define-color error_bg_color ${err};
        @define-color error_fg_color ${fg0};
        @define-color window_bg_color ${bg0};
        @define-color window_fg_color ${fg1};
        @define-color view_bg_color ${bg0};
        @define-color view_fg_color ${fg1};
        @define-color headerbar_bg_color ${bg1};
        @define-color headerbar_fg_color ${fg1};
        @define-color popover_bg_color ${bg1};
        @define-color popover_fg_color ${fg1};
        @define-color card_bg_color ${bg1};
        @define-color card_fg_color ${fg1};
        @define-color sidebar_bg_color ${bg1};
        @define-color sidebar_fg_color ${fg1};
        @define-color sidebar_border_color ${bg2};
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
