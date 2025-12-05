{ pkgs, lib, config, ... }: {
  options.fuzzel.enable = lib.mkEnableOption "fuzzel launcher";

  config = lib.mkIf config.fuzzel.enable {
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMono Nerd Font:size=14";
          terminal = "${pkgs.alacritty}/bin/alacritty";
          layer = "overlay";
        };
        colors = {
          background = "282c34ff";
          text = "abb2bfff";
          selection = "61afefff";
          selection-text = "282c34ff";
          border = "61afefff";
        };
        border = {
          width = 2;
          radius = 10;
        };
      };
    };
  };
}
