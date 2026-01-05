{ pkgs, lib, config, ... }:

{
  options.git.enable = lib.mkEnableOption "git";

  config = lib.mkIf config.git.enable {
    programs.git.enable = true;
  };
}
