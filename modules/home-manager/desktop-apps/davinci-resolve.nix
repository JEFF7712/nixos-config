{ pkgs, lib, config, ... }: {
  options.davinci-resolve.enable = lib.mkEnableOption "davinci resolve";

  config = lib.mkIf config.davinci-resolve.enable {
    home.packages = with pkgs; [
      (davinci-resolve.override (old: {
        buildFHSEnv = args: pkgs.buildFHSEnv (args // {
          extraBwrapArgs = (args.extraBwrapArgs or []) ++ [
            "--setenv QT_QPA_PLATFORM xcb"
            "--setenv LD_PRELOAD /usr/lib/libglib-2.0.so.0 /usr/lib/libgio-2.0.so.0 /usr/lib/libgmodule-2.0.so.0"
          ];
        });
      }))
    ];    
  };
}
