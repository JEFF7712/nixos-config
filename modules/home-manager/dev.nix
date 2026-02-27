{ pkgs, lib, config, inputs, ... }:

{
  options.dev.enable = lib.mkEnableOption "dev";

  config = lib.mkIf config.dev.enable (
    let
      claudeDesktop = inputs.claude-desktop.packages.${pkgs.system}.claude-desktop-with-fhs;
    in {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      home.packages = with pkgs; [
        geminicommit
        jq
        yq
        net-tools
        openssl_oqs
        tcpdump
        sops
        age
        dig
        glab
        claude-code
        (writeShellScriptBin "claude-desktop" ''
          export NIXOS_OZONE_WL=0
          export ELECTRON_OZONE_PLATFORM_HINT=x11
          exec ${claudeDesktop}/bin/claude-desktop \
            --ozone-platform=x11 \
            --use-gl=swiftshader \
            --enable-unsafe-swiftshader \
            --disable-gpu \
            "$@"
        '')
        opencode
        nodejs_24
        cloc
        codex
      ];
    }
  );
}
