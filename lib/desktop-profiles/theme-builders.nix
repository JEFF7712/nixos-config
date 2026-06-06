{
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
