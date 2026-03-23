{ lib, config, ... }:
{
  options.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/nixos";
    description = "Absolute path to the nixos config repo";
  };
}
