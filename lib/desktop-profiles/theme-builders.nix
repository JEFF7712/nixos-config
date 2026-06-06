{
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
