{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  cfg = config.homelab;
  managementUUID = "f8f12250-f96b-430b-8ce0-5b01becd1e4b";
  networkEvent = pkgs.writeShellApplication {
    name = "homelab-network-event";
    runtimeInputs = with pkgs; [
      coreutils
      iproute2
      jq
      systemd
      util-linux
    ];
    text = builtins.readFile ../../home/scripts/homelab-network-event;
  };
  tcpPorts = [
    7000
    7001
    7100
  ]
  ++ lib.optionals cfg.syncthing.enable [ 22000 ]
  ++ lib.optionals config.game.enable [
    27015
    27036
    27037
  ];
  udpPorts = [
    6000
    6001
    6002
    6003
    7011
  ]
  ++ lib.optionals cfg.syncthing.enable [
    21027
    22000
  ]
  ++ lib.optionals config.game.enable ([ 27015 ] ++ lib.range 27031 27036);
in
{
  options.homelab = {
    enable = lib.mkEnableOption "homelab networking (netbird, split DNS, mgmt routing, vpn, airplay)";
    managementInterface = lib.mkOption {
      type = lib.types.str;
      default = "enp0s13f0u1u1";
      description = "USB Ethernet interface connected to the homelab management network.";
    };
    trustedInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        cfg.managementInterface
        "wt0"
      ];
      description = "Interfaces allowed to receive AirPlay, Syncthing, and Steam traffic.";
    };
    trustedIPv4Ranges = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "10.0.0.0/16" ];
      description = "Home network sources allowed to use local services through Wi-Fi.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.networking.nftables.enable;
        message = "homelab source-scoped firewall rules require the iptables firewall backend.";
      }
    ];
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

    networking.networkmanager = {
      ensureProfiles.profiles.opnsense-lan-dhcp = {
        connection = {
          id = "opnsense-lan-dhcp";
          uuid = managementUUID;
          type = "ethernet";
          interface-name = cfg.managementInterface;
          autoconnect = true;
          autoconnect-priority = 100;
        };
        ipv4 = {
          method = "auto";
          route-metric = 700;
          never-default = true;
          route1 = "10.0.30.0/24,10.0.10.1,50";
        };
        ipv6.method = "disabled";
      };
      dispatcherScripts = [
        {
          type = "basic";
          source = pkgs.writeShellScript "homelab-network-event" ''
            export HOMELAB_MANAGEMENT_INTERFACE=${lib.escapeShellArg cfg.managementInterface}
            exec ${lib.getExe networkEvent} "$@"
          '';
        }
      ];
    };

    systemd.services.NetworkManager-ensure-profiles.preStart = ''
      ${pkgs.bash}/bin/bash ${../../home/scripts/preserve-management-profile} \
        /etc/NetworkManager/system-connections/opnsense-lan-dhcp.nmconnection ${managementUUID}
    '';

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

    networking.hosts = {
      "10.0.30.20" = [
        "git.internal"
        "s3.internal"
      ];
      "10.0.30.14" = [
        "ci.internal"
      ];
    };

    networking.firewall = {
      interfaces = lib.genAttrs cfg.trustedInterfaces (_: {
        allowedTCPPorts = tcpPorts;
        allowedUDPPorts = udpPorts;
      });
      extraCommands = lib.concatMapStringsSep "\n" (cidr: ''
        iptables -A nixos-fw -s ${lib.escapeShellArg cidr} -p tcp -m multiport --dports ${
          lib.concatMapStringsSep "," toString tcpPorts
        } -j nixos-fw-accept
        iptables -A nixos-fw -s ${lib.escapeShellArg cidr} -p udp -m multiport --dports ${
          lib.concatMapStringsSep "," toString udpPorts
        } -j nixos-fw-accept
      '') cfg.trustedIPv4Ranges;
    };

    environment.systemPackages = [
      inputs.globalprotect-openconnect.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.openconnect
      pkgs.uxplay
    ];
  };
}
