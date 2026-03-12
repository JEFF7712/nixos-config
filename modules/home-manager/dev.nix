{ pkgs, lib, config, inputs, ... }:

{
  options.dev.enable = lib.mkEnableOption "dev";

  config = lib.mkIf config.dev.enable {
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
        claude-desktop-fhs
        opencode
        nodejs_24
        cloc
        codex
        code-cursor
        gh
        glab
        bun
        pnpm
        ags
      ];
  };
}
