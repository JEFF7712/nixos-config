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
      # Upstream hardcodes AnchorNone; settings.json / niri layer-rules cannot move it.
      package =
        let
          base = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;
        in
        base.overrideAttrs (old: {
          pname = "${old.pname or "vicinae"}-top";
          postPatch = (old.postPatch or "") + ''
            substituteInPlace src/server/src/ui/qml/launcher/LauncherWindowLayerShell.qml \
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

    # Reapply only when profile state actually changed: full switch-profile
    # runs the whole transition pipeline on every switch otherwise. Stamp
    # covers active/variant plus every profile manifest (HM-refreshed).
    # Failures warn instead of dying silently; dry-activate must not mutate.
    home.activation.initVicinaeProfileTheme =
      lib.hm.dag.entryAfter
        [
          "writeBoundary"
          "initDesktopProfiles"
          "initDesktopProfileLiveConfigs"
        ]
        ''
          $DRY_RUN_CMD mkdir -p "${config.xdg.configHome}/vicinae/themes"
          if [ -x "$HOME/.local/bin/switch-profile" ]; then
            state_dir="$HOME/.local/state/desktop-profiles"
            stamp="$state_dir/reapply.stamp"
            sig=$(
              {
                cat "$HOME/.config/desktop-profiles/active" 2>/dev/null || true
                cat "$HOME/.config/desktop-profiles/active-variant" 2>/dev/null || true
                find "$HOME/.config/desktop-profiles" -name manifest.json -print0 2>/dev/null \
                  | sort -z | xargs -0 -r sha256sum
              } | sha256sum | cut -d' ' -f1
            )
            prev=$(cat "$stamp" 2>/dev/null || echo "")
            if [ "$prev" != "$sig" ]; then
              if [ -n "''${DRY_RUN_CMD:-}" ]; then
                $DRY_RUN_CMD "$HOME/.local/bin/switch-profile" --reapply
              else
                $DRY_RUN_CMD mkdir -p "$state_dir"
                if ! "$HOME/.local/bin/switch-profile" --reapply >/dev/null; then
                  echo "warning: switch-profile --reapply failed" >&2
                else
                  printf '%s' "$sig" > "$stamp"
                fi
              fi
            fi
          fi
        '';
  };
}
