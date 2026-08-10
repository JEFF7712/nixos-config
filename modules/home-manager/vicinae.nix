{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

{
  imports = [ inputs.vicinae.homeManagerModules.default ];

  options.vicinae.enable = lib.mkEnableOption "Vicinae desktop launcher";

  config = lib.mkIf config.vicinae.enable {
    programs.vicinae = {
      enable = true;
      # Pin the layer-shell surface to the top edge. Upstream hardcodes
      # AnchorNone (floating / compositor-default), and neither settings.json
      # nor niri layer-rules can move it. Compact mode expands downward from
      # the top, matching the built-in search-above-results layout.
      package =
        let
          base = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;
        in
        base.overrideAttrs (old: {
          pname = "${old.pname or "vicinae"}-top";
          postPatch = (old.postPatch or "") + ''
            substituteInPlace src/server/src/qml/qml/LauncherWindowLayerShell.qml \
              --replace-fail \
                'LayerShell.Window.anchors: LayerShell.Window.AnchorNone' \
                'LayerShell.Window.anchors: LayerShell.Window.AnchorTop'
          '';
        });
      # Belt-and-suspenders: VICINAE_OVERRIDES wins over the profile-written
      # settings.json so compact mode stays on even if a GUI edit clears it.
      settings = {
        launcher_window.compact_mode.enabled = true;
      };
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
