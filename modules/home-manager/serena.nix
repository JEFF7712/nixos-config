{
  pkgs,
  lib,
  config,
  ...
}:

let
  # Pinned Serena release. Bump deliberately; uvx caches the built env per ref.
  serenaRef = "v1.5.3";

  # Language servers for the languages actually used across these repos.
  # Baked onto the wrapper's PATH so Serena never tries to download its own
  # (dynamically-linked) servers — that download path is what breaks on NixOS.
  languageServers = with pkgs; [
    nixd # nix
    rust-analyzer # rust
    typescript-language-server # typescript / javascript
    bash-language-server # bash
    clang-tools # clangd -> c / c++
    pyright # python
    nodejs # required by the node-based servers above
  ];

  # Wrapper exposing `serena` with uv + git + every LSP on PATH. Using an
  # absolute, self-contained PATH also sidesteps the Codex env-passthrough
  # bug (oraios/serena#617), where the client drops PATH and the server times
  # out on launch.
  serena = pkgs.writeShellApplication {
    name = "serena";
    runtimeInputs = [
      pkgs.uv
      pkgs.git
    ]
    ++ languageServers;
    text = ''
      exec uvx --from "git+https://github.com/oraios/serena@${serenaRef}" serena "$@"
    '';
  };
in
{
  options.serena.enable = lib.mkEnableOption "Serena LSP-backed coding-agent MCP server";

  config = lib.mkIf config.serena.enable {
    home.packages = [ serena ];
  };
}
