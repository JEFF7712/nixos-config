{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.homelab-dns.enable = lib.mkEnableOption "homelab split DNS";

  config = lib.mkIf config.homelab-dns.enable {
    # When the homelab management link (10.0.10.0/24 over USB ethernet)
    # comes up, route only ~homelab through the homelab AdGuard instance.
    # General browsing keeps the current DNS, so unplugging or VPN
    # split-zones behave exactly as before. For full ad-blocking sessions,
    # temporarily run: resolvectl domain <iface> '~homelab ~.'
    networking.networkmanager.dispatcherScripts = [
      {
        type = "basic";
        source = pkgs.writeShellScript "homelab-dns" ''
          IFACE="$1"
          ACTION="$2"
          case "$ACTION" in
            up|reapply|connectivity-change|dhcp4-change)
              if ${pkgs.iproute2}/bin/ip -4 -o addr show dev "$IFACE" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q 'inet 10\.0\.10\.'; then
                ${pkgs.systemd}/bin/resolvectl dns "$IFACE" 10.0.30.10
                ${pkgs.systemd}/bin/resolvectl domain "$IFACE" '~homelab'
              fi
              ;;
          esac
        '';
      }
    ];
  };
}
