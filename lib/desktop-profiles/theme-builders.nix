rec {
  # GTK3 and GTK4 share the same color args; GTK4 has no unfocused_* support.
  mkGtkPair = args: {
    gtk3 = mkGtkColors args;
    gtk4 = mkGtkColors (builtins.removeAttrs args [ "unfocused" ]);
  };

  mkGtkColors =
    {
      accent,
      accentBg ? accent,
      accentFg,
      destructiveBg,
      destructiveFg,
      errorBg ? destructiveBg,
      errorFg ? destructiveFg,
      windowBg,
      windowFg,
      viewBg ? windowBg,
      viewFg ? windowFg,
      headerbarBg,
      headerbarFg ? windowFg,
      popoverBg,
      popoverFg ? windowFg,
      cardBg,
      cardFg ? windowFg,
      sidebarBg,
      sidebarFg ? windowFg,
      sidebarBorder,
      title ? null,
      headerbarBackdrop ? null,
      dialogBg ? null,
      dialogFg ? null,
      sidebarBackdrop ? null,
      secondarySidebarBg ? null,
      secondarySidebarFg ? null,
      unfocused ? null,
    }:
    ''
      ${if title == null then "" else "/* ${title} */"}
      @define-color accent_color ${accent};
      @define-color accent_bg_color ${accentBg};
      @define-color accent_fg_color ${accentFg};
      @define-color destructive_bg_color ${destructiveBg};
      @define-color destructive_fg_color ${destructiveFg};
      @define-color error_bg_color ${errorBg};
      @define-color error_fg_color ${errorFg};
      @define-color window_bg_color ${windowBg};
      @define-color window_fg_color ${windowFg};
      @define-color view_bg_color ${viewBg};
      @define-color view_fg_color ${viewFg};
      @define-color headerbar_bg_color ${headerbarBg};
      @define-color headerbar_fg_color ${headerbarFg};
      ${
        if headerbarBackdrop == null then
          ""
        else
          "@define-color headerbar_backdrop_color ${headerbarBackdrop};"
      }
      @define-color popover_bg_color ${popoverBg};
      @define-color popover_fg_color ${popoverFg};
      @define-color card_bg_color ${cardBg};
      @define-color card_fg_color ${cardFg};
      ${if dialogBg == null then "" else "@define-color dialog_bg_color ${dialogBg};"}
      ${if dialogFg == null then "" else "@define-color dialog_fg_color ${dialogFg};"}
      @define-color sidebar_bg_color ${sidebarBg};
      @define-color sidebar_fg_color ${sidebarFg};
      ${
        if sidebarBackdrop == null then "" else "@define-color sidebar_backdrop_color ${sidebarBackdrop};"
      }
      @define-color sidebar_border_color ${sidebarBorder};
      ${
        if secondarySidebarBg == null then
          ""
        else
          "@define-color secondary_sidebar_bg_color ${secondarySidebarBg};"
      }
      ${
        if secondarySidebarFg == null then
          ""
        else
          "@define-color secondary_sidebar_fg_color ${secondarySidebarFg};"
      }
      ${
        if unfocused == null then
          ""
        else
          ''
            @define-color theme_unfocused_fg_color ${unfocused.fg};
            @define-color theme_unfocused_text_color ${unfocused.text};
            @define-color theme_unfocused_bg_color ${unfocused.bg};
            @define-color theme_unfocused_base_color ${unfocused.base};
            @define-color theme_unfocused_selected_bg_color ${unfocused.selectedBg};
            @define-color theme_unfocused_selected_fg_color ${unfocused.selectedFg};
          ''
      }
    '';

  mkQt6ColorScheme =
    {
      active,
      disabled,
      inactive,
    }:
    let
      join = builtins.concatStringsSep ", ";
    in
    ''
      [ColorScheme]
      active_colors=${join active}
      disabled_colors=${join disabled}
      inactive_colors=${join inactive}
    '';

  # Role-based qt5ct/qt6ct color scheme. Slot order (22 entries):
  # WindowText, Button, Light, Midlight, Dark, Mid, Text, BrightText,
  # ButtonText, Base, Window, Shadow, Highlight, HighlightedText, Link,
  # LinkVisited, AlternateBase, ToolTipBase, ToolTipText, PlaceholderText,
  # <secondary>, Accent.
  mkQt6Roles =
    {
      windowText,
      button,
      midlight,
      mid,
      window,
      highlight,
      highlightedText,
      linkVisited,
      alternateBase,
      tooltipBase,
      tooltipText,
      secondaryText,
      disabledText,
      disabledHighlight,
      base ? window,
      link ? highlight,
      accent ? highlight,
      text ? windowText,
      buttonText ? windowText,
      placeholderText ? text,
      inactiveText ? text,
      inactiveWindowText ? inactiveText,
      inactiveButtonText ? inactiveText,
      inactivePlaceholderText ? inactiveText,
      inactiveSecondaryText ? secondaryText,
      disabledHighlightedText ? highlightedText,
      disabledLink ? disabledHighlight,
      disabledAccent ? disabledHighlight,
      disabledSecondaryText ? disabledText,
      light ? "#ffffff",
      brightText ? "#ffffff",
      shadow ? "#000000",
    }:
    mkQt6ColorScheme {
      active = [
        windowText
        button
        light
        midlight
        mid
        mid
        text
        brightText
        buttonText
        base
        window
        shadow
        highlight
        highlightedText
        link
        linkVisited
        alternateBase
        tooltipBase
        tooltipText
        placeholderText
        secondaryText
        accent
      ];
      disabled = [
        disabledText
        button
        light
        midlight
        mid
        mid
        disabledText
        brightText
        disabledText
        base
        window
        shadow
        disabledHighlight
        disabledHighlightedText
        disabledLink
        linkVisited
        alternateBase
        tooltipBase
        tooltipText
        disabledText
        disabledSecondaryText
        disabledAccent
      ];
      inactive = [
        inactiveWindowText
        button
        light
        midlight
        mid
        mid
        inactiveText
        brightText
        inactiveButtonText
        base
        window
        shadow
        highlight
        highlightedText
        link
        linkVisited
        alternateBase
        tooltipBase
        tooltipText
        inactivePlaceholderText
        inactiveSecondaryText
        accent
      ];
    };

  mkKittyColors =
    {
      cursor,
      cursorText,
      foreground,
      background,
      selectionForeground,
      selectionBackground,
      color0,
      color1,
      color2,
      color3,
      color4,
      color5,
      color6,
      color7,
      color8,
      color9,
      color10,
      color11,
      color12,
      color13,
      color14,
      color15,
      title ? null,
    }:
    ''
      ${if title == null then "" else "# ${title}"}
      cursor ${cursor}
      cursor_text_color ${cursorText}
      foreground ${foreground}
      background ${background}
      selection_foreground ${selectionForeground}
      selection_background ${selectionBackground}
      color0  ${color0}
      color8  ${color8}
      color1  ${color1}
      color9  ${color9}
      color2  ${color2}
      color10 ${color10}
      color3  ${color3}
      color11 ${color11}
      color4  ${color4}
      color12 ${color12}
      color5  ${color5}
      color13 ${color13}
      color6  ${color6}
      color14 ${color14}
      color7  ${color7}
      color15 ${color15}
    '';

  mkFishColors =
    {
      normal,
      command,
      keyword,
      quote,
      error,
      param,
      comment,
      selection,
      autosuggestion,
      redirection ? null,
      end ? null,
      searchMatch ? null,
      operator ? null,
      escape ? null,
    }:
    ''
      set -g fish_color_normal ${normal}
      set -g fish_color_command ${command}
      set -g fish_color_keyword ${keyword}
      set -g fish_color_quote ${quote}
      ${if redirection == null then "" else "set -g fish_color_redirection ${redirection}"}
      ${if end == null then "" else "set -g fish_color_end ${end}"}
      set -g fish_color_error ${error}
      set -g fish_color_param ${param}
      set -g fish_color_comment ${comment}
      set -g fish_color_selection --background=${selection}
      ${if searchMatch == null then "" else "set -g fish_color_search_match --background=${searchMatch}"}
      ${if operator == null then "" else "set -g fish_color_operator ${operator}"}
      ${if escape == null then "" else "set -g fish_color_escape ${escape}"}
      set -g fish_color_autosuggestion ${autosuggestion}
    '';

  mkStarshipPrompt =
    {
      success,
      error,
      directory,
      gitBranch,
      cmdDuration,
    }:
    ''
      format = "$all"

      [character]
      success_symbol = "[❯](${success})"
      error_symbol = "[❯](${error})"

      [directory]
      style = "bold ${directory}"

      [git_branch]
      style = "bold ${gitBranch}"

      [cmd_duration]
      style = "bold ${cmdDuration}"
    '';

  mkProfilePickerRofi =
    {
      background,
      text,
      border,
      selectedBackground,
      selectedForeground,
      inputBackground,
      prompt,
      placeholder,
      elementBackground,
      elementSelectedBackground,
      elementSelectedBorder,
      normalBackground ? background,
      windowBackground ? background,
      font ? "JetBrainsMono Nerd Font 11",
      textFont ? "JetBrainsMono Nerd Font 12",
      width ? 900,
      borderWidth ? 2,
      selectedBorderWidth ? borderWidth,
      windowRadius ? 8,
      inputRadius ? 6,
      elementRadius ? 6,
      iconRadius ? 4,
      inputBorder ? null,
      elementBorder ? null,
      placeholderText ? "Switch profile…",
    }:
    ''
      * {
          font:                        "${font}";
          background-color:            ${background};
          text-color:                  ${text};
          border-color:                ${border};
          selected-normal-background:  ${selectedBackground};
          selected-normal-foreground:  ${selectedForeground};
          normal-background:           ${normalBackground};
          normal-foreground:           ${text};
      }

      window {
          width:              ${toString width}px;
          border:             ${toString borderWidth}px solid;
          border-color:       ${border};
          border-radius:      ${toString windowRadius}px;
          padding:            12px;
          background-color:   ${windowBackground};
      }

      mainbox {
          spacing:            0;
          children:           [ inputbar, listview ];
      }

      inputbar {
          padding:            8px 12px;
          margin:             0 0 10px 0;
          background-color:   ${inputBackground};
          ${if inputBorder == null then "" else "border:             ${inputBorder};"}
          border-radius:      ${toString inputRadius}px;
          children:           [ prompt, entry ];
      }

      prompt {
          text-color:         ${prompt};
          padding:            0 8px 0 0;
      }

      entry {
          text-color:         ${text};
          placeholder:        "${placeholderText}";
          placeholder-color:  ${placeholder};
      }

      listview {
          columns:            3;
          lines:              2;
          spacing:            10px;
          fixed-height:       false;
          scrollbar:          false;
      }

      element {
          orientation:        vertical;
          padding:            10px;
          spacing:            8px;
          border-radius:      ${toString elementRadius}px;
          background-color:   ${elementBackground};
          ${if elementBorder == null then "" else "border:             ${elementBorder};"}
          cursor:             pointer;
      }

      element selected {
          background-color:   ${elementSelectedBackground};
          border:             ${toString selectedBorderWidth}px solid;
          border-color:       ${elementSelectedBorder};
      }

      element-icon {
          size:               160px;
          border-radius:      ${toString iconRadius}px;
          horizontal-align:   0.5;
      }

      element-text {
          horizontal-align:   0.5;
          vertical-align:     0.5;
          text-color:         inherit;
          font:               "${textFont}";
      }
    '';

  # btop theme file (~/.config/btop/themes/). One low→mid→high gradient is
  # applied to every gradient group (cpu, temp, mem, net, process).
  mkBtopTheme =
    {
      mainBg,
      mainFg,
      hiFg,
      selectedBg,
      inactiveFg,
      procMisc,
      box,
      gradLow,
      gradMid,
      gradHigh,
      title ? mainFg,
      selectedFg ? hiFg,
      graphText ? mainFg,
      meterBg ? selectedBg,
    }:
    let
      gradient = group: ''
        theme[${group}_start]="${gradLow}"
        theme[${group}_mid]="${gradMid}"
        theme[${group}_end]="${gradHigh}"
      '';
    in
    ''
      theme[main_bg]="${mainBg}"
      theme[main_fg]="${mainFg}"
      theme[title]="${title}"
      theme[hi_fg]="${hiFg}"
      theme[selected_bg]="${selectedBg}"
      theme[selected_fg]="${selectedFg}"
      theme[inactive_fg]="${inactiveFg}"
      theme[graph_text]="${graphText}"
      theme[meter_bg]="${meterBg}"
      theme[proc_misc]="${procMisc}"
      theme[cpu_box]="${box}"
      theme[mem_box]="${box}"
      theme[net_box]="${box}"
      theme[proc_box]="${box}"
      theme[div_line]="${box}"
    ''
    + builtins.concatStringsSep "" (
      map gradient [
        "temp"
        "cpu"
        "free"
        "cached"
        "available"
        "used"
        "download"
        "upload"
        "process"
      ]
    );

  # tmux status/pane colors, sourced from ~/.config/tmux/profile-colors.conf.
  mkTmuxColors =
    {
      bg,
      fg,
      accent,
      inactive,
      secondary ? accent,
      border ? inactive,
      activeBorder ? accent,
    }:
    ''
      set -g status-style "bg=${bg},fg=${fg}"
      set -g status-left-style "fg=${accent},bold"
      set -g status-right-style "fg=${secondary}"
      set -g window-status-current-style "fg=${accent},bold"
      set -g window-status-style "fg=${inactive}"
      set -g pane-border-style "fg=${border}"
      set -g pane-active-border-style "fg=${activeBorder}"
      set -g message-style "bg=${bg},fg=${accent}"
      set -g mode-style "bg=${accent},fg=${bg}"
      set -g clock-mode-colour "${accent}"
    '';

  # hyprlock $variables, sourced from ~/.config/hypr/profile-colors.conf.
  # hyprlang colors are rgb(RRGGBB)/rgba(RRGGBBAA) without the leading '#',
  # so hex palette colors are converted; alphas are hex suffixes.
  mkHyprlockColors =
    {
      fg,
      muted,
      accent,
      surface,
      surfaceAlt,
      error,
      border ? accent,
      surfaceAlpha ? "d9",
      surfaceAltAlpha ? "c8",
      borderAlpha ? "e6",
      errorAlpha ? "e6",
    }:
    let
      hex = c: builtins.substring 1 6 c;
      rgb = c: "rgb(${hex c})";
      rgba = c: a: "rgba(${hex c}${a})";
    in
    ''
      $fg = ${rgb fg}
      $muted = ${rgb muted}
      $accent = ${rgb accent}
      $surface = ${rgba surface surfaceAlpha}
      $surface_alt = ${rgba surfaceAlt surfaceAltAlpha}
      $border = ${rgba border borderAlpha}
      $error = ${rgba error errorAlpha}
    '';

  # cava [color] section, swapped into ~/.config/cava/config by
  # apply_cava_colors. cava requires hex colors to be quoted.
  mkCavaColors =
    {
      gradLow,
      gradMid,
      gradHigh,
      foreground ? gradHigh,
    }:
    ''
      [color]
      foreground = '${foreground}'
      gradient = 1
      gradient_color_1 = '${gradLow}'
      gradient_color_2 = '${gradMid}'
      gradient_color_3 = '${gradHigh}'
    '';

  mkMakoConfig =
    {
      background,
      text,
      border,
      highBackground,
      highBorder,
      highText,
      lowBorder,
      font ? "JetBrainsMono Nerd Font 11",
      borderSize ? 2,
      borderRadius ? 8,
      width ? 320,
      padding ? 12,
      margin ? 10,
      defaultTimeout ? 5000,
      lowTimeout ? 3000,
      highTimeout ? 0,
      maxIconSize ? 48,
    }:
    ''
      font=${font}
      background-color=${background}
      text-color=${text}
      border-color=${border}
      border-size=${toString borderSize}
      border-radius=${toString borderRadius}
      width=${toString width}
      padding=${toString padding}
      margin=${toString margin}
      default-timeout=${toString defaultTimeout}
      icons=1
      max-icon-size=${toString maxIconSize}
      layer=overlay

      [urgency=low]
      border-color=${lowBorder}
      default-timeout=${toString lowTimeout}

      [urgency=high]
      background-color=${highBackground}
      border-color=${highBorder}
      text-color=${highText}
      default-timeout=${toString highTimeout}
    '';
}
