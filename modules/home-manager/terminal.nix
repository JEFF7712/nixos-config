{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

{
  options.terminal.enable = lib.mkEnableOption "user terminal config";
  imports = [ inputs.nixvim.homeModules.nixvim ];

  config = lib.mkIf config.terminal.enable {

    programs.nixvim = {
      enable = true;
      nixpkgs.source = inputs.nixpkgs;
      colorschemes.oxocarbon.enable = true;
      opts = {
        number = true;
        shiftwidth = 2;
        expandtab = true;
      };

      plugins = {
        lualine.enable = true;
        web-devicons.enable = true;
        telescope.enable = true;
        treesitter.enable = true;
        neo-tree.enable = true;

        cmp = {
          enable = true;
          settings.sources = [
            { name = "nvim_lsp"; }
            { name = "path"; }
            { name = "buffer"; }
          ];
          settings.mapping = {
            "<C-Space>" = "cmp.mapping.complete()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
          };
        };

        lsp = {
          enable = true;
          servers = {
            nixd.enable = true;
            pyright.enable = true;
            clangd.enable = true;
          };
        };
      };
    };

    home.packages = with pkgs; [
      eza
      bat
      fzf
      kitty
    ];

    programs.tealdeer.enable = true;

    programs.bash = {
      enable = true;
      initExtra = builtins.readFile ../../home/configs/bashrc/.bashrc;
    };
    programs.fish = {
      enable = true;
      shellAliases = {
        cniri = "$EDITOR ${config.repoPath}/home/configs/niri/config.kdl";
        ls = "eza --icons";
        ll = "eza -l --icons";
        l = "eza --icons";
        lt = "eza --tree --level=2 --icons";
        ltt = "eza --tree --level=3 --icons";
        la = "eza -a --icons";
        lla = "eza -la --icons";
        cd = "z";
        cds = "zi";
        kprune = "kubectl delete pods -A --field-selector=status.phase=Failed,status.phase=Succeeded,status.phase==Completed";
        gg = "git add . && gmc && git push";
        cities = "env WINEDLLOVERRIDES='d3d11=n,b;dxgi=n,b' __NV_PRIME_RENDER_OFFLOAD=1 __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only wine ~/games/cities-skylines-II/Cities2.exe";
        stellaris = "env WINEDLLOVERRIDES='d3d11=n,b;dxgi=n,b' __NV_PRIME_RENDER_OFFLOAD=1 __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only wine ~/games/stellaris/stellaris.exe";
        factorio = "env WINEDLLOVERRIDES='d3d11=n,b;dxgi=n,b' __NV_PRIME_RENDER_OFFLOAD=1 __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only wine ~/games/Factorio/bin/x64/factorio.exe";
        # niri/PRIME: force X11/GLX + NVIDIA so CUDA↔OpenGL interop works (bare davinci-resolve false-OOMs)
        resolve = "env QT_QPA_PLATFORM=xcb QT_XCB_GL_INTEGRATION=glx __NV_PRIME_RENDER_OFFLOAD=1 __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json DRI_PRIME=1 davinci-resolve";
        zed = "zeditor";
        njs = "cd ${config.repoPath} && just switch";
        njst = "cd ${config.repoPath} && sudo (readlink -f (command -v nixos-rebuild)) test --flake path:${config.repoPath}#laptop";
        njp = "cd ${config.repoPath} && nix fmt . && git add -A && gmc -y && git push";
        nju = "cd ${config.repoPath} && just update";
        ngc = "cd ${config.repoPath} && just gc";
      };
      shellAbbrs = {
        sp = "switch-profile";
        k = "kubectl";
        t = "talosctl";
        tf = "terragrunt";
        zz = "zeditor .";
        ga = "git add .";
        gs = "git status";
        gp = "git push";
        gd = "git diff";
        gl = "git log";
        cc = "cursor .";
        claude = "claude --dangerously-skip-permissions";
        codex = "codex --yolo";
        opencode = "opencode --auto";
        pi = "pi --approve";
        agent = "env AGENT_CLI_DISABLE_HALF_BLOCK_PROMPT_BAR=true agent --force";
        muse = "muse --yolo";
        ci = "$HOME/projects/ci-dashboard.sh";
      };
      interactiveShellInit = ''
        set fish_greeting ""
        set -gx STARSHIP_CONFIG $HOME/.config/starship_matugen.toml
        # Cursor Agent's ▄/▀ prompt padding is opaque foreground; Kitty can only
        # tint matching cell backgrounds. Keep the bar as a background fill.
        set -gx AGENT_CLI_DISABLE_HALF_BLOCK_PROMPT_BAR true
      '';
    };

    programs.starship = {
      enable = true;
    };

    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
