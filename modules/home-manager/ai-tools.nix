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
      let
        system = pkgs.stdenv.hostPlatform.system;
      in
      (with pkgs; [
        claude-code
        opencode
        codex
        mcp-nixos
      ])
      ++ [
        inputs.nix-agent.packages.${system}.default
      ];
  };
}
