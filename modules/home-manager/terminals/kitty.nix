{ pkgs, lib, config, ... }: {
  options.kitty.enable = lib.mkEnableOption "kitty terminal";

  config = lib.mkIf config.kitty.enable {
    programs.kitty = {
      enable = true;
      extraConfig = builtins.readFile ../configs/kitty/kitty.conf;
    };
    programs.bash = {
      enable = true;
      initExtra = builtins.readFile ../configs/bashrc/.bashrc;
    };
  };
}
