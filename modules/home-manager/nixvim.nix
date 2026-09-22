{
  inputs,
  lib,
  config,
  ...
}:

{
  options.nixvim.enable = lib.mkEnableOption "nixvim editor config";

  # Kept out of terminal.nix so hosts that never want the LSP toolchain
  # (~1.6G: clang/llvm/pyright) simply do not import this module.
  imports = [ inputs.nixvim.homeModules.nixvim ];

  config = lib.mkIf config.nixvim.enable {
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
  };
}
