{
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
