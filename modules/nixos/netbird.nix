{ pkgs, lib, config, ... }:

let
  netbirdUiPatched = pkgs.netbird-ui.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      substituteInPlace "$out/share/applications/netbird.desktop" \
        --replace-fail "Exec=netbird-ui" "Exec=$out/bin/netbird-ui"
    '';
  });
in

{
  options.netbird.enable = lib.mkEnableOption "netbird";

  config = lib.mkIf config.netbird.enable {
    services.netbird.enable = true;
    services.netbird.ui.package = netbirdUiPatched;
  };
}
