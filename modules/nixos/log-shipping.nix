# Ships the journal to the homelab's in-cluster Loki, so its journal alert
# rules (homelab gitops/observability/loki/rules-configmap.yaml) and ntfy
# routing cover the laptop. Labels and component names mirror homelab's
# flake/modules/host-log-shipping.nix; the push policy there admits the
# laptop's reserved Wi-Fi and management addresses, and NetBird masquerades
# off-LAN pushes to an admitted address.
{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.logShipping;
in
{
  options.homelab.logShipping = {
    enable = lib.mkEnableOption "shipping the system journal to the homelab Loki";
    lokiAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.0.40.17";
      description = "IPv4 address of the homelab loki-push VIP; the unit may connect only here.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.alloy = {
      enable = true;
      extraFlags = [
        "--server.http.listen-addr=127.0.0.1:12345"
        "--storage.path=/var/lib/alloy/data"
        "--disable-reporting"
      ];
    };

    environment.etc."alloy/config.alloy".text = ''
      logging {
        level = "warn"
      }

      loki.source.journal "journal" {
        path          = "/var/log/journal"
        relabel_rules = discovery.relabel.journal.rules
        forward_to    = [loki.write.local.receiver]
        labels        = { component = "system-journal" }
      }

      discovery.relabel "journal" {
        targets = []

        rule {
          source_labels = ["__journal__hostname"]
          target_label  = "hostname"
        }

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }

        rule {
          source_labels = ["__journal_priority_keyword"]
          target_label  = "level"
        }

        rule {
          source_labels = ["__journal__transport"]
          target_label  = "transport"
        }
      }

      loki.write "local" {
        endpoint {
          url = "http://${cfg.lokiAddress}/loki/api/v1/push"
        }
      }
    '';

    # Static account so the persisted read position keeps a stable owner.
    users.users.alloy = {
      isSystemUser = true;
      group = "alloy";
      description = "Grafana Alloy journal shipper";
    };
    users.groups.alloy = { };

    systemd.services.alloy = {
      environment.GOMEMLIMIT = "160MiB";
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "alloy";
        Group = "alloy";
        SupplementaryGroups = [ "systemd-journal" ];
        RestartSec = lib.mkForce 10;

        MemoryHigh = "256M";
        MemoryMax = "384M";
        CPUQuota = "25%";
        Nice = 10;

        IPAddressDeny = "any";
        IPAddressAllow = [
          "localhost"
          cfg.lokiAddress
        ];

        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectProc = "invisible";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
        UMask = "0077";
      };
    };

    preservation.preserveAt."/persist".directories = lib.mkIf config.impermanence.enable [
      {
        directory = "/var/lib/alloy";
        user = "alloy";
        group = "alloy";
        mode = "0700";
      }
    ];
  };
}
