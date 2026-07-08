{
  inputs,
  lib,
  config,
  ...
}:

{
  imports = [ inputs.vicinae.homeManagerModules.default ];

  options.vicinae.enable = lib.mkEnableOption "Vicinae desktop launcher";

  config = lib.mkIf config.vicinae.enable {
    programs.vicinae = {
      enable = true;
      systemd = {
        enable = true;
        autoStart = true;
        environment.USE_LAYER_SHELL = 1;
      };
    };

    home.activation.initVicinaeProfileTheme =
      lib.hm.dag.entryAfter
        [
          "writeBoundary"
          "initDesktopProfiles"
        ]
        ''
          mkdir -p "${config.xdg.configHome}/vicinae/themes"
          if [ -x "$HOME/.local/bin/switch-profile" ]; then
            "$HOME/.local/bin/switch-profile" --reapply >/dev/null 2>&1 || true
          fi
        '';
  };
}
