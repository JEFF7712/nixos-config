{ pkgs, lib, config, ... }: {
  options.davinci-resolve.enable = lib.mkEnableOption "davinci resolve";

  config = lib.mkIf config.davinci-resolve.enable {
    home.packages = with pkgs; [
      (davinci-resolve.override (old: {
        buildFHSEnv = args: pkgs.buildFHSEnv (args // {
          extraBwrapArgs = (args.extraBwrapArgs or []) ++ [
            "--setenv QT_QPA_PLATFORM xcb"
          ];
        });
      }))
    ];    
  };
}
