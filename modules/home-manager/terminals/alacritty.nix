{ pkgs, lib, config, ... }: {
  options.alacritty.enable = lib.mkEnableOption "alacritty terminal";

  config = lib.mkIf config.alacritty.enable {
    programs.alacritty = {
      enable = true;
      settings = {
        window = {
          padding = { x = 10; y = 10; };
          opacity = 0.95;
          decorations = "none";
        };
        font = {
          size = 12.0;
          normal.family = "JetBrainsMono Nerd Font";
        };
        # One Dark Theme (Example)
        colors.primary = {
          background = "#282c34";
          foreground = "#abb2bf";
        };
      };
    };
  };
}
