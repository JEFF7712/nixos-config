{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  options.cli-tools.enable = lib.mkEnableOption "cli tools";

  config = lib.mkIf config.cli-tools.enable {
    home.packages =
      let
        inherit (pkgs.stdenv.hostPlatform) system;
      in
      with pkgs;
      [
        tmux
        btop
        ffmpeg
        parted
        smartmontools
        ncdu
        yazi
        unrar
        inotify-tools
        mtr
        just
        ripgrep
        fd
        ast-grep
        dust
        hyperfine
        difftastic
        watchexec
        nvd
        nix-output-monitor
        nixfmt
        shellcheck
        nurl
        nix-init
      ]
      ++ [
        inputs.compchem-cctop.packages.${system}.default
        inputs.mercury-cli.packages.${system}.default
      ];
  };
}
