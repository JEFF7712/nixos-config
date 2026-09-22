{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.obsidian;
  vaultObsidian = "${cfg.vaultPath}/.obsidian";
  newsreader = pkgs.google-fonts.override { fonts = [ "Newsreader" ]; };
  configRoot = "${config.repoPath}/home/configs/obsidian";
in
{
  options.obsidian = {
    enable = lib.mkEnableOption "Obsidian vault font/CSS sync";

    vaultPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/obsidian/vaults/main";
      description = "Absolute path to the Obsidian vault whose .obsidian/ config is managed";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.obsidian
      newsreader
    ];

    # Live-editable sources: edit in ~/nixos, then rebuild (or re-run activation)
    # to sync into the vault. Out-of-store so the repo stays the source of truth.
    home.file."${lib.removePrefix "${config.home.homeDirectory}/" vaultObsidian}/snippets/code-blocks.css" =
      {
        source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/snippets/code-blocks.css";
        force = true;
      };

    home.file."${lib.removePrefix "${config.home.homeDirectory}/" vaultObsidian}/plugins/custom-font-loader/data.json" =
      {
        source = config.lib.file.mkOutOfStoreSymlink "${configRoot}/plugins/custom-font-loader/data.json";
        force = true;
      };

    # Custom Font Loader needs real TTFs; merge appearance.json without clobbering iris theme fields.
    # One failed command under set -e aborts the entire home-manager activation,
    # so only scaffold once the vault exists and only merge when Obsidian has
    # actually created appearance.json.
    home.activation.syncObsidianVaultConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -euo pipefail
      vault=${lib.escapeShellArg vaultObsidian}
      fonts_dir="$vault/fonts"
      appearance="$vault/appearance.json"
      newsreader_src=${lib.escapeShellArg "${newsreader}/share/fonts/truetype"}

      if [ -d "$vault" ]; then
        mkdir -p "$fonts_dir" "$vault/snippets" "$vault/plugins/custom-font-loader"

        # google-fonts ships variable faces as Newsreader[opsz,wght].ttf etc.
        roman=$(find "$newsreader_src" -maxdepth 1 -name 'Newsreader*.ttf' ! -iname '*italic*' | head -n1 || true)
        italic=$(find "$newsreader_src" -maxdepth 1 -name 'Newsreader*Italic*.ttf' | head -n1 || true)
        if [ -n "$roman" ]; then
          cp -f "$roman" "$fonts_dir/Newsreader.ttf"
        fi
        if [ -n "$italic" ]; then
          cp -f "$italic" "$fonts_dir/Newsreader-Italic.ttf"
        fi
        chmod u+w "$fonts_dir"/Newsreader*.ttf 2>/dev/null || true

        # Drop the plugin's cached base64 CSS so it regenerates from the new TTF.
        rm -f "$vault/plugins/custom-font-loader"/newsreader*.css

        if [ -f "$appearance" ]; then
          ${pkgs.jq}/bin/jq --indent 2 '
            .textFontFamily = "Newsreader"
            | .interfaceFontFamily = "IBM Plex Sans"
            | .monospaceFontFamily = "IBM Plex Mono"
            | .enabledCssSnippets = (
                ((.enabledCssSnippets // []) + ["code-blocks"])
                | unique
              )
          ' "$appearance" > "$appearance.tmp" \
            && mv "$appearance.tmp" "$appearance" \
            || rm -f "$appearance.tmp"
        fi
      fi
    '';
  };
}
