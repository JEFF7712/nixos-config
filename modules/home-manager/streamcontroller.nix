# Stream Deck via StreamController: pinned store plugins, pages and the
# UsageBars plugin linked from the repo, and a user service instead of the
# app's own XDG autostart entry.
{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.streamcontroller;
  home = config.home.homeDirectory;
  dataDir = ".var/app/com.core447.StreamController/data";
  repoDir = "${config.repoPath}/home/configs/streamcontroller";

  storePlugin =
    owner: repo: rev: hash:
    pkgs.fetchFromGitHub {
      inherit
        owner
        repo
        rev
        hash
        ;
    };

  # Commits match StreamController's store entries for app 1.5.0-beta.
  plugins = {
    com_core447_MediaPlugin =
      storePlugin "StreamController" "MediaPlugin" "f4be6cb3db50657b7d4a2f6ed9eecf415c382035"
        "sha256-1bOWWrM3vNTv9etLubyQOuk4fCF/q6uWrGXW8IakBSA=";
    com_core447_OSPlugin =
      storePlugin "StreamController" "OSPlugin" "a8d943f41fe468fc4c978d3266fbfcf260e2598b"
        "sha256-ZSOH1byGhLH9GcTn9tVJP9N4ZRZnfFu0EVc/TnaNUXM=";
    com_core447_DeckPlugin =
      storePlugin "StreamController" "DeckPlugin" "e99ef07b992c4fcbf31b5f7b0dd7e17b221931ef"
        "sha256-xHpJNpi78RaHI/+RGEbS/Z4rQMp+rHPg9AxgBLKTcog=";
    HomeAssistantPlugin =
      storePlugin "gensyn" "HomeAssistantPlugin" "f82334d96a1cbd977614bc4773cadbf0742ab728"
        "sha256-HSfF3bOSe6XRmP6DUGjGZs6ePnNlPa932IJL+v2LMUg=";
  };

  pages = [
    "Main"
    "AI"
    "Printer"
    "Spotify"
  ];

  # The app rewrites these files at runtime, so merge in the keys we own
  # rather than linking them read-only.
  prepare = pkgs.writeShellScript "streamcontroller-prepare" ''
    set -eu
    settings="${home}/${dataDir}/settings"
    mkdir -p "$settings/plugins/HomeAssistantPlugin"

    merge() {
      local file=$1 filter=$2
      [ -s "$file" ] || echo '{}' >"$file"
      ${pkgs.jq}/bin/jq "$filter" "$file" >"$file.tmp" && mv "$file.tmp" "$file"
    }

    merge "$settings/settings.json" '.store["auto-update"] = false | .system.autostart = false'
    merge "$settings/pages.json" \
      '.["default-pages"]["${cfg.deckSerial}"] = "${home}/${dataDir}/pages/Main.json"'

    if [ -r /run/secrets/hass-token ]; then
      umask 077
      ${pkgs.jq}/bin/jq -n --rawfile token /run/secrets/hass-token '{
        "file-version": "2.0",
        settings: {
          host: "${cfg.homeAssistantHost}",
          port: "443",
          ssl: true,
          verify_certificate: true,
          token: ($token | rtrimstr("\n"))
        }
      }' >"$settings/plugins/HomeAssistantPlugin/settings.json"
    fi
  '';
in
{
  options.streamcontroller = {
    enable = lib.mkEnableOption "StreamController for the Stream Deck";
    deckSerial = lib.mkOption {
      type = lib.types.str;
      default = "A00DA6261LQJ";
      description = "Serial of the deck that opens on the Main page.";
    };
    homeAssistantHost = lib.mkOption {
      type = lib.types.str;
      default = "ha.rupan.dev";
      description = "Home Assistant host for the HA plugin (token from sops hass-token).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.streamcontroller ];

    home.file =
      lib.mapAttrs' (id: src: lib.nameValuePair "${dataDir}/plugins/${id}" { source = src; }) plugins
      // {
        "${dataDir}/plugins/com_rupan_UsageBars".source =
          config.lib.file.mkOutOfStoreSymlink "${repoDir}/UsageBars";
      }
      // lib.listToAttrs (
        map (
          page:
          lib.nameValuePair "${dataDir}/pages/${page}.json" {
            source = config.lib.file.mkOutOfStoreSymlink "${repoDir}/pages/${page}.json";
          }
        ) pages
      );

    systemd.user.services.streamcontroller = {
      Unit = {
        Description = "StreamController (Stream Deck)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStartPre = "${prepare}";
        ExecStart = "${pkgs.streamcontroller}/bin/streamcontroller -b";
        # Keys run deck-ha, matrix-sync, profile-dispatch and codex.
        Environment = "PATH=${home}/.local/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
