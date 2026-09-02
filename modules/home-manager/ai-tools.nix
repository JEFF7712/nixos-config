{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  options.ai-tools.enable = lib.mkEnableOption "ai-tools";

  config = lib.mkIf config.ai-tools.enable (
    let
      inherit (pkgs.stdenv.hostPlatform) system;
      claudeCode = inputs.claude-code-nix.packages.${system}.claude-code;

      mkClaudeProxyLauncher =
        {
          name,
          model,
          smallModel,
          autoCompactWindow ? null,
        }:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = with pkgs; [
            coreutils
            curl
            systemd
          ];
          text = ''
            set -eu

            systemctl --user start claude-code-proxy.service

            attempts=0
            until curl --fail --silent http://127.0.0.1:18765/healthz >/dev/null; do
              attempts=$((attempts + 1))
              if [ "$attempts" -ge 50 ]; then
                echo "claude-code-proxy did not become healthy" >&2
                systemctl --user status claude-code-proxy.service --no-pager >&2 || true
                exit 1
              fi
              sleep 0.1
            done

            export ANTHROPIC_BASE_URL=http://127.0.0.1:18765
            export ANTHROPIC_AUTH_TOKEN=unused
            export ANTHROPIC_MODEL=${lib.escapeShellArg model}
            export ANTHROPIC_SMALL_FAST_MODEL=${lib.escapeShellArg smallModel}
            export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
            export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
            export CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK=1
            export CLAUDE_CODE_MAX_RETRIES=3
            ${lib.optionalString (autoCompactWindow != null) ''
              export CLAUDE_CODE_AUTO_COMPACT_WINDOW=${toString autoCompactWindow}
            ''}

            exec ${lib.getExe claudeCode} "$@"
          '';
        };

      claudeCodex = mkClaudeProxyLauncher {
        name = "claude-codex";
        model = "gpt-5.6-sol[1m]";
        smallModel = "gpt-5.6-luna[1m]";
        autoCompactWindow = 272000;
      };

      claudeGrok = mkClaudeProxyLauncher {
        name = "claude-grok";
        model = "cursor:cursor-grok-4.5-high";
        smallModel = "cursor:cursor-grok-4.5-high";
      };

      # Do not wrap with `export GITHUB_PAT_TOKEN`: Codex ignores it, and a
      # session-wide export leaks the PAT via /proc/<pid>/environ.
      codexCli = inputs.codex-cli-nix.packages.${system}.default;
      opencodeCli = inputs.opencode-nix.packages.${system}.opencode;
      piCli = inputs.opencode-nix.packages.${system}.pi;
    in
    {
      home.packages =
        (with pkgs; [
          mcp-nixos
          poppler-utils
          pandoc
          file
          sox
          rtk
          claude-code-proxy
          muse-code
        ])
        ++ [
          opencodeCli
          piCli
          codexCli
          claudeCode
          claudeCodex
          claudeGrok
          inputs.terax.packages.${system}.default
        ];

      xdg.configFile."rtk/config.toml".text = ''
        # RTK config. Partial - unspecified sections use built-in defaults.

        [hooks]
        exclude_commands = ["git diff", "git status", "rg"]

        [telemetry]
        enabled = false
      '';

      systemd.user.services.claude-code-proxy = {
        Unit = {
          Description = "Claude Code multi-model proxy";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          ExecStart = "${lib.getExe pkgs.claude-code-proxy} serve --no-monitor";
          Restart = "on-failure";
          RestartSec = "2s";
        };
      };
    }
  );
}
