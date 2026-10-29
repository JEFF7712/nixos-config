{
  pkgs,
  lib,
  config,
  ...
}:
let
  # The upstream bundle includes Firefox/WebKit even for a Chromium-only MCP.
  # Keep its matching driver and CLI, but build only Chromium's browser links.
  playwrightPackages = pkgs.callPackage "${pkgs.path}/pkgs/development/web/playwright/driver.nix" {
    linkFarm =
      name: entries:
      pkgs.linkFarm name (
        lib.filterAttrs (
          browserName: _: lib.hasPrefix "chromium" browserName || lib.hasPrefix "ffmpeg-" browserName
        ) entries
      );
  };
  playwrightMcp = pkgs.playwright-mcp.override {
    playwright-driver = playwrightPackages.playwright-core;
    inherit (playwrightPackages) playwright-test;
  };
  python = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
  registration = pkgs.runCommand "agent-browser-registration" { nativeBuildInputs = [ python ]; } ''
    python -m unittest discover -s ${../../lib/agent-browser} -p test_register.py -v
    install -Dm644 ${../../lib/agent-browser/register.py} "$out/register.py"
  '';
in
{
  options.agent-browser.enable = lib.mkEnableOption "agent-browser";

  config = lib.mkIf config.agent-browser.enable {
    fonts.fontconfig.enable = true;
    home.packages =
      let
        browser = pkgs.writeShellApplication {
          name = "agent-browser-mcp";
          runtimeInputs = [ pkgs.coreutils ];
          text = ''
            umask 077
            root="''${XDG_STATE_HOME:-$HOME/.local/state}/agent-browser"
            mkdir -p "$root"
            output=$(mktemp -d "$root/session-XXXXXXXX")
            exec ${lib.getExe playwrightMcp} \
              --headless --isolated --browser chromium \
              --output-dir "$output" "$@"
          '';
        };
      in
      [
        browser
        pkgs.dejavu_fonts
        pkgs.noto-fonts-color-emoji
        playwrightPackages.playwright-test
        (pkgs.writeShellApplication {
          name = "agent-browser-check";
          text = ''
            exec ${lib.getExe pkgs.python3} ${../../lib/agent-browser/check.py} \
              --command ${lib.getExe browser} "$@"
          '';
        })
      ];

    # Merge only our server into mutable client settings. Managing entire files
    # would overwrite provider settings, plugin registrations and trusted projects.
    home.activation.agentBrowser = lib.hm.dag.entryAfter [ "installPackages" ] ''
      run ${lib.getExe python} ${registration}/register.py \
        --home ${lib.escapeShellArg config.home.homeDirectory} \
        --command ${lib.escapeShellArg "${config.home.profileDirectory}/bin/agent-browser-mcp"}
    '';
  };
}
