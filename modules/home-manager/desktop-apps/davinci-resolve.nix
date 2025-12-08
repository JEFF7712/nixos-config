{ pkgs, lib, config, ... }: 
let
  unstableTarball = builtins.fetchTarball {
    url = "https://github.com/nixos/nixpkgs/archive/nixos-unstable.tar.gz";
    sha256 = "003z6rp3b69pcn8v34b1mq69w1bh2gilyrcvbnn626rci37dcqq6"; 
  };

  unstable = import unstableTarball {
    system = pkgs.stdenv.hostPlatform.system; # Fixes the "system renamed" warning
    config = {
      allowUnfree = true;
    };
  };
in
{
  options.davinci-resolve.enable = lib.mkEnableOption "davinci resolve";

  config = lib.mkIf config.davinci-resolve.enable {
    home.packages = [
      (unstable.davinci-resolve.override (old: {
        buildFHSEnv = args: pkgs.buildFHSEnv (args // {
          extraBwrapArgs = (args.extraBwrapArgs or []) ++ [
            "--setenv QT_QPA_PLATFORM xcb"
          ];
        });
      }))
    ];    
  };
}
