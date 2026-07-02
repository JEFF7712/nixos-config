{ lib, config, ... }:
{
  options.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/nixos";
    description = "Absolute path to the nixos config repo";
  };

  options.assetsPath = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/nixos-assets";
    description = "Absolute path to the assets repo (wallpapers, previews); kept out of the flake so source copies stay small";
  };
}
