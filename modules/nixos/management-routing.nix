{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.management-routing.enable = lib.mkEnableOption "management VLAN source-based routing";

  config = lib.mkIf config.management-routing.enable {
    # Register the mgmt routing table so `ip route add table mgmt` succeeds.
    environment.etc."iproute2/rt_tables".text = ''
      #
      # reserved values
      #
      255	local
      254	main
      253	default
      0	unspec
      #
      # local
      #
      #1	inr.ruhep
      1001	mgmt
    '';
    networking.networkmanager.dispatcherScripts = [
      {
        type = "basic";
        source = pkgs.writeShellScript "management-routing" ''
          set -e
          IFACE="$1"
          ACTION="$2"
          case "$ACTION" in
            up|reapply|connectivity-change|dhcp4-change)
              if ${pkgs.iproute2}/bin/ip -4 -o addr show dev "$IFACE" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q 'inet 10\.0\.10\.'; then
                SRC="$(${pkgs.iproute2}/bin/ip -4 -o addr show dev "$IFACE" | ${pkgs.gnugrep}/bin/grep 'inet 10\.0\.10\.' | ${pkgs.gawk}/bin/gawk '{print $4}' | ${pkgs.coreutils}/bin/cut -d/ -f1)"
                if [ -n "$SRC" ]; then
                  # `ip rule` has no `replace`, only `add` and `del`. Wipe any
                  # stale rule for this source first so we don't trip EEXIST.
                  ${pkgs.iproute2}/bin/ip rule del from "$SRC" lookup mgmt priority 100 2>/dev/null || true
                  ${pkgs.iproute2}/bin/ip route replace default via 10.0.10.1 dev "$IFACE" metric 50 table mgmt 2>/dev/null || true
                  ${pkgs.iproute2}/bin/ip route replace 10.0.30.0/24 via 10.0.10.1 dev "$IFACE" metric 50 table mgmt 2>/dev/null || true
                  ${pkgs.iproute2}/bin/ip rule add from "$SRC" lookup mgmt priority 100
                fi
              fi
              ;;
            down)
              ${pkgs.iproute2}/bin/ip rule del from 10.0.10.0/24 lookup mgmt priority 100 2>/dev/null || true
              ${pkgs.iproute2}/bin/ip route flush table mgmt 2>/dev/null || true
              ;;
          esac
        '';
      }
    ];
  };
}
