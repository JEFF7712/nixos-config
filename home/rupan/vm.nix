{ config, pkgs, ... }:
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
      # Agent shells are non-interactive, so direnv never loads the homelab
      # dev shell; keep its live cluster tools on PATH directly.
      kubectl
      kubernetes-helm
      fluxcd
      sops
      age
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
  # Lets the Claude mobile app and claude.ai/code start sessions here, like
  # the Codex app-server daemon. Each session gets its own homelab worktree;
  # capacity stays low because all sessions share the guest's 8 GiB.
  systemd.user.services.claude-remote-control = {
    Unit.Description = "Claude Code Remote Control server";
    Service = {
      WorkingDirectory = "%h/workspace/homelab";
      Environment = [
        "PATH=${config.home.profileDirectory}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
      ];
      ExecStart = "${config.home.profileDirectory}/bin/claude remote-control --spawn worktree --no-create-session-in-dir --capacity 4 --permission-mode bypassPermissions";
      Restart = "on-failure";
      RestartSec = 30;
    };
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.tmpfiles.rules = [
    "d %h/workspace 0750 - - -"
  ];
}
