{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.syncthing;
in
{
  options.homelab.syncthing = {
    enable = lib.mkEnableOption "Syncthing client to back up laptop data to homelab NAS";
    nasAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.0.30.20";
      description = "IP address or hostname of nas-01.";
    };
    guiAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8384";
      description = "Web GUI listen address on laptop (loopback only).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = "rupan";
      group = "users";
      dataDir = "/home/rupan";
      configDir = "/home/rupan/.config/syncthing";
      inherit (cfg) guiAddress;
      openDefaultPorts = true;
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        options = {
          urAccepted = -1; # Disable telemetry / usage reporting
          crashReportingEnabled = false; # Disable crash reports
          globalAnnounceEnabled = false; # Disable public announce servers
          localAnnounceEnabled = true; # LAN multicast discovery
          relaysEnabled = false; # Disable public relay servers
          natEnabled = false; # Disable UPnP / NAT-PMP port mapping
        };
        devices = {
          "nas-01" = {
            id = "JA3XY2G-IRMRCXV-ZD2UTD5-KXKSCBS-B32V4M6-Y5XBNAZ-VKZBLDF-SYRUQQB";
            addresses = [
              "tcp://${cfg.nasAddress}:22000"
              "quic://${cfg.nasAddress}:22000"
            ];
          };
        };
        folders =
          let
            buildIgnores = [
              "node_modules"
              "target"
              ".direnv"
              "result"
              "result-*"
              ".venv"
              "venv"
              "__pycache__"
              "*.pyc"
              ".build"
              "build"
              "dist"
              ".mypy_cache"
              ".pytest_cache"
              ".ruff_cache"
            ];
            mkSendOnlyFolder =
              id: path: extra:
              {
                inherit id path;
                devices = [ "nas-01" ];
                type = "sendonly";
                rescanIntervalS = 3600;
              }
              // extra;
          in
          {
            "laptop-documents-personal" =
              mkSendOnlyFolder "laptop-documents-personal" "/home/rupan/documents"
                { };
            "laptop-documents-apps" = mkSendOnlyFolder "laptop-documents-apps" "/home/rupan/Documents" { };
            "laptop-projects" = mkSendOnlyFolder "laptop-projects" "/home/rupan/projects" {
              ignorePatterns = buildIgnores;
            };
            "laptop-code" = mkSendOnlyFolder "laptop-code" "/home/rupan/code" {
              ignorePatterns = buildIgnores;
            };
            "laptop-school" = mkSendOnlyFolder "laptop-school" "/home/rupan/school" {
              ignorePatterns = buildIgnores;
            };
            "laptop-businesses" = mkSendOnlyFolder "laptop-businesses" "/home/rupan/businesses" {
              ignorePatterns = buildIgnores;
            };
            "laptop-research" = mkSendOnlyFolder "laptop-research" "/home/rupan/research" {
              ignorePatterns = buildIgnores;
            };
            "laptop-homelab" = mkSendOnlyFolder "laptop-homelab" "/home/rupan/homelab" {
              ignorePatterns = buildIgnores;
            };
            "laptop-nixos" = mkSendOnlyFolder "laptop-nixos" config.repoPath {
              ignorePatterns = buildIgnores;
            };
            "laptop-obsidian" = mkSendOnlyFolder "laptop-obsidian" "/home/rupan/obsidian" { };
            "laptop-media" = mkSendOnlyFolder "laptop-media" "/home/rupan/media" { };
            "laptop-videos" = mkSendOnlyFolder "laptop-videos" "/home/rupan/Videos" { };
          };
      };
    };
  };
}
