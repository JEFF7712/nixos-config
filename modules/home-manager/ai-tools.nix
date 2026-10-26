{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  options.ai-tools.enable = lib.mkEnableOption "ai-tools";
  options.ai-tools.desktop = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install graphical AI applications alongside the shared CLI tools.";
  };

  config = lib.mkIf config.ai-tools.enable (
    let
      inherit (pkgs.stdenv.hostPlatform) system;
      claudeCode = inputs.claude-code-nix.packages.${system}.claude-code;

      # Do not wrap with `export GITHUB_PAT_TOKEN`: Codex ignores it, and a
      # session-wide export leaks the PAT via /proc/<pid>/environ.
      codexCli = inputs.codex-cli-nix.packages.${system}.default;
      opencodeCli = inputs.opencode-nix.packages.${system}.opencode;
      piCli = inputs.opencode-nix.packages.${system}.pi;
      antigravity = inputs.antigravity-nix.packages.${system}.default;
      antigravityCli = inputs.antigravity-nix.packages.${system}.google-antigravity-cli;
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
          muse-code
          tea
        ])
        ++ [
          opencodeCli
          piCli
          codexCli
          claudeCode
        ]
        ++ lib.optional config.ai-tools.desktop antigravity
        ++ [ antigravityCli ];

      xdg.configFile."rtk/config.toml".text = ''
        # RTK config. Partial - unspecified sections use built-in defaults.

        [hooks]
        exclude_commands = ["git diff", "git status", "rg"]

        [telemetry]
        enabled = false
      '';
    }
  );
}
