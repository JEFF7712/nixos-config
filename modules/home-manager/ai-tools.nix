{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  deepagents = pkgs.python3Packages.buildPythonApplication rec {
    pname = "deepagents";
    version = "0.5.0";
    pyproject = true;

    src = inputs.deepagents + "/libs/deepagents";

    build-system = with pkgs.python3Packages; [
      setuptools
      wheel
    ];

    pythonRelaxDeps = [ "langchain-anthropic" "langchain-core" ];

    dependencies = with pkgs.python3Packages; [
      langchain
      langchain-anthropic
      langchain-google-genai
      langchain-core
      wcmatch
    ];

    pythonImportsCheck = [ "deepagents" ];
  };
in
{
  options.ai-tools.enable = lib.mkEnableOption "ai-tools";

  config = lib.mkIf config.ai-tools.enable {
    home.packages =
      (with pkgs; [
        claude-code
        opencode
        codex
        deepagents
        mcp-nixos
      ])
      ++ [
        inputs.nix-agent.packages.${pkgs.system}.default
      ];
  };
}
