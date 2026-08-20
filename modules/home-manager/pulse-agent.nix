{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.pulseAgent;

  pulseRun = pkgs.writeShellApplication {
    name = "pulse-agent-run";
    runtimeInputs = [ pkgs.uv ];
    text = ''
      set -euo pipefail
      cd "${cfg.projectPath}"
      exec uv run pulse run --host ${lib.escapeShellArg cfg.listenHost} --port ${toString cfg.port}
    '';
  };
in
{
  options.pulseAgent = {
    enable = lib.mkEnableOption ''
      Pulse personal intelligence agent (systemd user unit, `uv run` from projectPath).
      Stop any Docker container bound to the same port first. After switching, run
      `systemctl --user enable --now pulse-agent.service`.
    '';

    projectPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/projects/pulse";
      description = "Git checkout of pulse; `uv sync` should have been run there at least once.";
    };

    listenHost = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Bind address for the web UI (passed to `pulse run --host`). Loopback by default.
        Override only if you intentionally want non-local access; open the host firewall
        yourself in that case.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Listen port for the web UI (passed to `pulse run --port`).";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Extra environment variables for the service (e.g. `PULSE_CONFIG_DIR`,
        `PULSE_DATABASE_PATH`, `PULSE_VAULT_PATH`). Values are passed through systemd `Environment=`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pulseRun ];

    systemd.user.services.pulse-agent = {
      Unit = {
        Description = "Pulse personal intelligence agent";
        After = [ "network.target" ];
      };
      Service = {
        ExecStart = lib.getExe pulseRun;
        Restart = "on-failure";
        RestartSec = 5;
      }
      // lib.optionalAttrs (cfg.extraEnvironment != { }) {
        Environment = lib.mapAttrsToList (n: v: "${n}=${v}") cfg.extraEnvironment;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
