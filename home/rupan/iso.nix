{
  pkgs,
  ...
}:

{
  # Curated list (not import-tree): recovery image enables a handful of
  # features; the full module tree drags in nixvim's LSP toolchain, vicinae,
  # ai-tools, and every profile just to mkForce most of it off again.
  imports = [
    ./home.nix
    ../../modules/home-manager/repo-path.nix
    ../../modules/home-manager/terminal.nix
    ../../modules/home-manager/niri.nix
    ../../modules/home-manager/noctalia.nix
    ../../modules/home-manager/desktop-profiles.nix
  ];

  # Install/recovery media, not a daily driver. common-apps (calibre, spotify
  # + spicetify, vscode and its extensions, vesktop, zoom, zed), cli-toys, and
  # the bulk of cli-tools (ffmpeg, cctop, mercury, ast-grep, nix-init) are off:
  # they pushed the image past GitHub's hard 2 GiB release-asset ceiling. What
  # is left is what you want with a broken disk in front of you.
  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    papirus-icon-theme
    networkmanagerapplet
    parted
    smartmontools
    ncdu
    tree
    tmux
    btop
    yazi
    ripgrep
    fd
    just
    nvd
    nix-output-monitor
  ];

  # common-apps used to supply this. When the only machine you own will not
  # boot, a browser is the difference between recovering and not.
  programs.firefox.enable = true;

  niri.enable = true;
  noctalia.enable = true;
  terminal.enable = true;

  # Runtime theme switching costs ~1G here, most of it six cursor themes that
  # each profile pins plus matugen/imagemagick. noctalia's ExecCondition falls
  # back to "noctalia" when the active-profile file is missing, so the shell
  # still comes up; it just comes up unthemed. nixvim.nix is not imported, so
  # the LSP toolchain never evaluates on this host.
  desktopProfiles.enable = false;

  # Scripts — symlink home/scripts/ into ~/.local/bin
  home.file.".local/bin" = {
    source = ../scripts;
    recursive = true;
    executable = true;
  };

  home.sessionPath = [ "$HOME/.local/bin" ];

  qt.enable = true;
}
