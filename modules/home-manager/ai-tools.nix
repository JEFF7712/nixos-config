{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  options.ai-tools.enable = lib.mkEnableOption "ai-tools";
  options.agentConfig.enable = lib.mkEnableOption "shared Claude and Codex agent configuration";

  config = lib.mkMerge [
    (lib.mkIf config.ai-tools.enable (
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

        # Upstream codex-cli-nix omits codex-code-mode-host, which is required
        # for command execution.
        codexCli = pkgs.callPackage ../../pkgs/codex-cli {
          codex-upstream = inputs.codex-cli-nix.packages.${system}.default;
        };
        codexWithGithubToken = pkgs.writeShellScriptBin "codex" ''
          if [ -z "''${GITHUB_PAT_TOKEN:-}" ]; then
            export GITHUB_PAT_TOKEN="$(${lib.getExe pkgs.gh} auth token)"
          fi

          exec ${lib.getExe codexCli} "$@"
        '';
      in
      {
        home.packages =
          (with pkgs; [
            opencode
            mcp-nixos
            poppler-utils
            pandoc
            file
            sox
            rtk
            claude-code-proxy
          ])
          ++ [
            codexWithGithubToken
            claudeCode
            claudeCodex
            claudeGrok
            inputs.nix-agent.packages.${system}.default
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
    ))

    (lib.mkIf config.agentConfig.enable (
      let
        syncClaudeCodexConfig = pkgs.writeShellApplication {
          name = "sync-claude-codex-config";
          runtimeInputs = with pkgs; [
            coreutils
            findutils
            gawk
            jq
          ];
          text = ''
            set -eu

            claude_dir="${config.home.homeDirectory}/.claude"
            claude_skills="$claude_dir/skills"
            claude_instructions="$claude_dir/CLAUDE.md"
            claude_settings="$claude_dir/settings.json"
            claude_installed_plugins="$claude_dir/plugins/installed_plugins.json"
            codex_dir="${config.home.homeDirectory}/.codex"
            codex_skills="$codex_dir/skills"
            codex_instructions="$codex_dir/AGENTS.md"

            mkdir -p "$codex_dir" "$codex_skills"

            link_codex_skill() {
              source_path="$1"
              name="$2"

              case "$name" in
                .*|"")
                  return 0
                  ;;
              esac

              target="$codex_skills/$name"
              if [ -e "$target" ] && [ ! -L "$target" ]; then
                echo "Skipping $target because it is not a symlink" >&2
              else
                ln -sfn "$source_path" "$target"
              fi
            }

            if [ -d "$claude_skills" ]; then
              find "$claude_skills" -mindepth 1 -maxdepth 1 -print | while IFS= read -r skill; do
                link_codex_skill "$skill" "$(basename "$skill")"
              done
            fi

            if [ -f "$claude_settings" ] && [ -f "$claude_installed_plugins" ]; then
              jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$claude_settings" |
                while IFS= read -r plugin_key; do
                  plugin_name="''${plugin_key%@*}"
                  install_path="$(
                    jq -r --arg key "$plugin_key" '.plugins[$key][0].installPath // empty' "$claude_installed_plugins"
                  )"

                  if [ -z "$install_path" ] || [ ! -d "$install_path" ]; then
                    continue
                  fi

                  if [ -f "$install_path/SKILL.md" ]; then
                    link_codex_skill "$install_path" "$plugin_name"
                  fi

                  for skills_dir in "$install_path/skills" "$install_path/.claude/skills"; do
                    if [ -d "$skills_dir" ]; then
                      find "$skills_dir" -mindepth 1 -maxdepth 1 -type d -print |
                        while IFS= read -r skill; do
                          if [ -f "$skill/SKILL.md" ]; then
                            link_codex_skill "$skill" "$(basename "$skill")"
                          fi
                        done
                    fi
                  done
                done
            fi

            if [ -f "$claude_instructions" ]; then
              {
                echo "# AGENTS.md"
                echo
                echo "Generated by Home Manager from $claude_instructions."
                echo "Edit the Claude file, then wait for the sync timer or run sync-claude-codex-config."
                echo
                awk '
                  $0 == "# Delegating to codex" { skip = 1; next }
                  skip && /^# / { skip = 0 }
                  !skip { print }
                ' "$claude_instructions"
              } > "$codex_instructions"
            fi
          '';
        };
      in
      {
        home.packages = [ syncClaudeCodexConfig ];

        home.activation.syncClaudeCodexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${lib.getExe syncClaudeCodexConfig}
        '';

        systemd.user.services.sync-claude-codex-config = {
          Unit = {
            Description = "Sync Claude agent config into Codex";
          };
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe syncClaudeCodexConfig;
          };
        };

        systemd.user.timers.sync-claude-codex-config = {
          Unit = {
            Description = "Periodically sync Claude agent config into Codex";
          };
          Timer = {
            OnBootSec = "2m";
            OnUnitActiveSec = "5m";
            Unit = "sync-claude-codex-config.service";
          };
          Install = {
            WantedBy = [ "timers.target" ];
          };
        };
      }
    ))
  ];
}
