{ lib, config, ... }:

{
  options.vicinae.enable = lib.mkEnableOption "Vicinae desktop launcher";

  config = lib.mkIf config.vicinae.enable {
    nix.settings = {
      extra-substituters = [ "https://vicinae.cachix.org" ];
      extra-trusted-public-keys = [ "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc=" ];
    };
  };
}
