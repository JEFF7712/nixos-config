{ pkgs, lib, config, ... }: {
  options.direnv.enable = lib.mkEnableOption "direnv";

  config = lib.mkIf config.direnv.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
