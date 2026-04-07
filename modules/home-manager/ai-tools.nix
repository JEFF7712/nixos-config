{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  options.ai-tools.enable = lib.mkEnableOption "ai-tools";

  config = lib.mkIf config.ai-tools.enable {
    home.packages =
      (with pkgs; [
        claude-code
        opencode
        codex
        mcp-nixos
      ])
      ++ [
        inputs.nix-agent.packages.${pkgs.system}.default
      ];
  };
}
