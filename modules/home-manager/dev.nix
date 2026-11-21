{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  options.dev.enable = lib.mkEnableOption "dev";

  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  config = lib.mkIf config.dev.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Homelab pull-through cache (nas-01), reachable on the LAN or over
    # NetBird; without either pass --registry=https://registry.npmjs.org/.
    programs.npm = {
      enable = true;
      package = null;
      settings = {
        prefix = "${config.home.homeDirectory}/.local";
        registry = "https://npm.rupan.dev/";
      };
    };

    programs.nix-index.enable = true;
    programs.nix-index-database.comma.enable = true;

    home.packages =
      with pkgs;
      [
        geminicommit
        jq
        yq
        net-tools
        openssl_oqs
        tcpdump
        dig
        glab
        nodejs_24
        cloc
        gh
        bun
        pnpm
        uv
        ruff
        awscli
      ]
      ++ [ inputs.code-cursor-nix.packages.${pkgs.stdenv.hostPlatform.system}.cursor ];
  };
}
