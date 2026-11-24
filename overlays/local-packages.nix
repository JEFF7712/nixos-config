{ vicinae }:
final: prev: {
  plymouth-nixos-logo = final.callPackage ../pkgs/plymouth-nixos-logo { };
  muse-code = final.callPackage ../pkgs/muse-code { };
  iris-python = final.callPackage ../pkgs/iris-python { };
  calendar-python = final.callPackage ../pkgs/calendar-python { };
  hass-bridge = final.callPackage ../pkgs/hass-bridge { };
  matrix-playback = final.callPackage ../pkgs/matrix-playback { };
  folio-page = final.callPackage ../pkgs/folio-page { };
  seg6-ws = final.callPackage ../pkgs/seg6-ws { };
  # Upstream hardcodes AnchorNone; settings.json / niri layer-rules cannot move it.
  # Shared between security.wrappers.vicinae-input-server and home-manager so
  # laptop builds Vicinae once instead of twice.
  vicinae-top = vicinae.packages.${prev.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    pname = "${old.pname or "vicinae"}-top";
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/server/src/ui/qml/launcher/LauncherWindowLayerShell.qml \
        --replace-fail \
          'LayerShell.Window.anchors: LayerShell.Window.AnchorNone' \
          'LayerShell.Window.anchors: LayerShell.Window.AnchorTop'
    '';
  });
}
