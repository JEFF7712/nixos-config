{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  cfg = config.homelab;
in
{
  options.homelab.enable = lib.mkEnableOption "homelab networking (netbird, split DNS, mgmt routing, vpn, airplay)";

  config = lib.mkIf cfg.enable {
    services.netbird.enable = true;

    systemd.services.netbird-restart-on-resume = {
      description = "Restart NetBird after resume from sleep";
      wantedBy = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
        "suspend-then-hibernate.target"
      ];
      after = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
        "suspend-then-hibernate.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl restart netbird.service";
      };
    };

    networking.networkmanager.dispatcherScripts = [
      {
        type = "basic";
        source = pkgs.writeShellScript "homelab-dns" ''
          IFACE="$1"
          ACTION="$2"
          case "$ACTION" in
            up|reapply|connectivity-change|dhcp4-change)
              if ${pkgs.iproute2}/bin/ip -4 -o addr show dev "$IFACE" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q 'inet 10\\.0\\.10\\.'; then
                ${pkgs.systemd}/bin/resolvectl dns "$IFACE" 10.0.30.10
                ${pkgs.systemd}/bin/resolvectl domain "$IFACE" '~homelab'
              fi
              ;;
          esac
        '';
      }
      {
        type = "basic";
        source = pkgs.writeShellScript "management-routing" ''
          set -e
          IFACE="$1"
          ACTION="$2"
          case "$ACTION" in
            up|reapply|connectivity-change|dhcp4-change)
              if ${pkgs.iproute2}/bin/ip -4 -o addr show dev "$IFACE" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q 'inet 10\\.0\\.10\\.'; then
                SRC="$(${pkgs.iproute2}/bin/ip -4 -o addr show dev "$IFACE" | ${pkgs.gnugrep}/bin/grep 'inet 10\\.0\\.10\\.' | ${pkgs.gawk}/bin/gawk '{print $4}' | ${pkgs.coreutils}/bin/cut -d/ -f1)"
                if [ -n "$SRC" ]; then
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

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
        userServices = true;
      };
    };
    networking.firewall = {
      allowedTCPPorts = [
        7000
        7001
        7100
      ];
      allowedUDPPorts = [
        5353
        6000
        6001
        6002
        6003
        7011
      ];
    };

    environment.systemPackages = [
      inputs.globalprotect-openconnect.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.openconnect
      pkgs.uxplay
    ];
  };
}
