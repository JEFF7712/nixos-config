{ pkgs, ... }:
{
  imports = [
    ../../modules/home-manager/ai-tools.nix
    ../../modules/home-manager/agent-browser.nix
  ];

  agent-browser.enable = true;

  home = {
    username = "developer";
    homeDirectory = "/home/developer";
    stateVersion = "26.05";
    sessionVariables.EDITOR = "nvim";
    packages = with pkgs; [
      git
      gh
      neovim
      ripgrep
      fd
      jq
      just
      rsync
      curl
      wget
      unzip
      file
      gcc
      gnumake
      pkg-config
      python3
      uv
      ruff
      nodejs_24
      pnpm
      nixfmt
      statix
      deadnix
      shellcheck
      btop
      ncdu
    ];
  };
  ai-tools = {
    enable = true;
    desktop = false;
  };
  programs = {
    home-manager.enable = true;
    bash.enable = true;
    fish = {
      enable = true;
      interactiveShellInit = "set fish_greeting";
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    tmux = {
      enable = true;
      terminal = "tmux-256color";
      historyLimit = 50000;
      extraConfig = ''
        set -g mouse on
        set -g destroy-unattached off
      '';
    };
    git = {
      enable = true;
      settings = {
        user.name = "JEFF7712";
        user.email = "rupanpandyan@gmail.com";
        init.defaultBranch = "main";
      };
    };
  };
  systemd.user.tmpfiles.rules = [
    "d %h/workspace 0750 - - -"
  ];
}
