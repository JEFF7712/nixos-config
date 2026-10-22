{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.workstation;
  pipewire = config.services.pipewire.package;

  rtpTarget = "10.0.30.20";
  rtpPort = 46100;
  boseSink = "bluez_output.E4_58_BC_10_CA_C9.1";

  # The bedroom RTP feed runs as its own PipeWire client process, not inside
  # the main daemon. module-rtp-sink opens its socket once per stream start
  # and never retries: a connect() that fails during a network change
  # ("Network is unreachable") leaves the node running with no socket and the
  # lights dark until the module reloads. Reloading it here is a unit restart
  # that leaves Bose playback and app streams untouched.
  bedroomRtpConf = pkgs.writeText "bedroom-rtp.conf" (
    builtins.toJSON {
      "context.spa-libs" = {
        "audio.convert.*" = "audioconvert/libspa-audioconvert";
        "support.*" = "support/libspa-support";
      };
      "context.modules" = [
        {
          name = "libpipewire-module-rt";
          args = { };
          flags = [
            "ifexists"
            "nofail"
          ];
        }
        { name = "libpipewire-module-protocol-native"; }
        { name = "libpipewire-module-client-node"; }
        { name = "libpipewire-module-adapter"; }
        # Deliberately RTP and not RAOP/AirPlay: PipeWire 1.6.8's RAOP sender
        # aborts on shairport-sync's handshake (rtsp-client.c:397). net.ttl
        # must stay above 1 because nas-01 is a router hop away. Opt-in per
        # app via pavucontrol; never the default sink.
        {
          name = "libpipewire-module-rtp-sink";
          args = {
            "destination.ip" = rtpTarget;
            "destination.port" = rtpPort;
            "net.ttl" = 64;
            "sess.name" = "bedroom-rtp";
            "audio.rate" = 48000;
            "audio.channels" = 2;
            "stream.props" = {
              "media.class" = "Audio/Sink";
              "node.name" = "bedroom-rtp-out";
              "node.description" = "Bedroom RTP to NAS";
            };
          };
        }
        # Copy whatever plays on the Bose into the RTP feed so nas LedFx music
        # mode follows laptop audio with no per-app routing. Audio goes to the
        # Bose directly; only the lights copy takes the RTP path.
        # dont-fallback makes WirePlumber wait for (and relink to) the named
        # targets instead of falling back to the default sink, which would
        # either copy the wrong output or loop the Bose into itself.
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.description" = "Bose to bedroom RTP mirror";
            "audio.position" = [
              "FL"
              "FR"
            ];
            "capture.props" = {
              "node.name" = "input.laptop-rtp-mirror";
              "target.object" = boseSink;
              "stream.capture.sink" = true;
              "node.dont-fallback" = true;
            };
            "playback.props" = {
              "node.name" = "output.laptop-rtp-mirror";
              "target.object" = "bedroom-rtp-out";
              "node.dont-fallback" = true;
            };
          };
        }
      ];
    }
  );

  bedroomRtpWatchdog = pkgs.writeShellApplication {
    name = "bedroom-rtp-watchdog";
    runtimeInputs = [
      pipewire
      pkgs.iproute2
      pkgs.jq
      pkgs.systemd
      pkgs.coreutils
    ];
    text = ''
      systemctl --user is-active --quiet bedroom-rtp.service || exit 0
      ip route get ${rtpTarget} >/dev/null 2>&1 || exit 0

      problem() {
        local dump state bose capture
        dump=$(pw-dump 2>/dev/null) || return 1
        state=$(jq -r '[.[] | select(.type == "PipeWire:Interface:Node" and .info.props["node.name"] == "bedroom-rtp-out") | .info.state] | if length == 0 then "" elif any(. == "running") then "running" else .[0] end' <<<"$dump")
        if [ -z "$state" ]; then
          echo "bedroom-rtp-out node missing"
          return 0
        fi
        if [ "$state" = running ] && [ -z "$(ss -Hun dst ${rtpTarget}:${toString rtpPort})" ]; then
          echo "bedroom-rtp-out running without a socket"
          return 0
        fi
        bose=$(jq -r 'first(.[] | select(.type == "PipeWire:Interface:Node" and .info.props["node.name"] == "${boseSink}") | .id) // empty' <<<"$dump")
        capture=$(jq -r 'first(.[] | select(.type == "PipeWire:Interface:Node" and .info.props["node.name"] == "input.laptop-rtp-mirror") | .id) // empty' <<<"$dump")
        # module-loopback destroys itself when its capture target vanishes,
        # so a Bose reconnect leaves this process without a mirror.
        if [ -n "$bose" ] && [ -z "$capture" ]; then
          echo "mirror missing while the Bose is connected"
          return 0
        fi
        if [ -n "$bose" ] && ! jq -e --argjson o "$bose" --argjson i "$capture" \
          'any(.[]; .type == "PipeWire:Interface:Link" and .info["output-node-id"] == $o and .info["input-node-id"] == $i)' <<<"$dump" >/dev/null; then
          echo "mirror not linked to the Bose"
          return 0
        fi
        return 1
      }

      reason=$(problem) || exit 0
      sleep 3
      reason=$(problem) || exit 0
      echo "restarting bedroom-rtp: $reason"
      systemctl --user restart bedroom-rtp.service
    '';
  };
in
{
  options.workstation.enable =
    lib.mkEnableOption "desktop workstation base (audio, bluetooth, input, file manager, utils, git, launcher cache)"
    // {
      default = true;
    };

  config = lib.mkIf cfg.enable {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Experimental = true;
        };
      };
    };
    services.blueman.enable = true;

    systemd.user.services.bedroom-rtp = {
      description = "Bedroom RTP feed to nas-01 (Bose mirror for LedFx lights)";
      after = [
        "pipewire.service"
        "wireplumber.service"
      ];
      requires = [ "pipewire.service" ];
      partOf = [ "pipewire.service" ];
      wantedBy = [ "default.target" ];
      restartTriggers = [ bedroomRtpConf ];
      serviceConfig = {
        ExecStart = "${pipewire}/bin/pipewire -c ${bedroomRtpConf}";
        Restart = "always";
        RestartSec = "2s";
      };
    };

    systemd.user.services.bedroom-rtp-watchdog = {
      description = "Restart the bedroom RTP feed when it silently stops sending";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe bedroomRtpWatchdog;
      };
    };

    systemd.user.timers.bedroom-rtp-watchdog = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnStartupSec = "30s";
        OnUnitActiveSec = "15s";
        AccuracySec = "1s";
      };
    };

    services.libinput.enable = true;
    services.hardware.bolt.enable = true;

    programs.thunar = {
      enable = true;
      plugins = with pkgs; [
        thunar-archive-plugin
        thunar-volman
      ];
    };
    programs.xfconf.enable = true;
    services.gvfs.enable = true;
    services.tumbler.enable = true;
    xdg.mime = {
      defaultApplications = {
        "inode/directory" = "thunar.desktop";
        "application/x-directory" = "thunar.desktop";
      };
      addedAssociations = {
        "inode/directory" = [ "thunar.desktop" ];
        "application/x-directory" = [ "thunar.desktop" ];
      };
      removedAssociations = {
        "inode/directory" = [
          "org.gnome.Nautilus.desktop"
          "nautilus.desktop"
          "org.kde.dolphin.desktop"
          "dolphin.desktop"
          "nemo.desktop"
          "pcmanfm.desktop"
          "caja.desktop"
        ];
        "application/x-directory" = [
          "org.gnome.Nautilus.desktop"
          "nautilus.desktop"
          "org.kde.dolphin.desktop"
          "dolphin.desktop"
          "nemo.desktop"
          "pcmanfm.desktop"
          "caja.desktop"
        ];
      };
    };

    services.usbmuxd.enable = true;

    systemd.tmpfiles.rules = [
      "e /home/rupan/media/images/screenshots - - - 30d"
    ];

    programs.git = {
      enable = true;
      config = {
        user.name = "JEFF7712";
        user.email = "rupanpandyan@gmail.com";
        credential."https://github.com".helper = "!gh auth git-credential";
        credential."https://gist.github.com".helper = "!gh auth git-credential";
        init.defaultBranch = "main";
        safe.directory = config.repoPath;
        diff.external = lib.getExe pkgs.difftastic;
      };
    };

    nix.settings = {
      extra-substituters = [ "https://vicinae.cachix.org" ];
      extra-trusted-public-keys = [ "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc=" ];
    };

    environment.systemPackages = with pkgs; [
      pavucontrol
      brightnessctl
      playerctl
      dualsensectl
      zip
      unzip
      libimobiledevice
      ifuse
      gphoto2
    ];
  };
}
