{ lib, ... }:
{
  options.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "/home/rupan/nixos";
    description = "Absolute path to the nixos config repo";
  };
}
