{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.obsidian;
  vaultObsidian = "${cfg.vaultPath}/.obsidian";
  cmuFonts = pkgs.cm_unicode;
  configRoot = "${config.repoPath}/home/configs/obsidian";
  cupertinoTheme = pkgs.fetchFromGitHub {
    owner = "svnaxis";
    repo = "obsidian-cupertino";
    rev = "31eb16ffa00d46ac4f83d5ce8b808c548e7b5740";
    hash = "sha256-ATwILAnbjBGQXhLrGbmM3ojslGmunK+U77erCGCF2ac=";
  };
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
      cmuFonts
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

    # Custom Font Loader needs real font files; merge appearance.json without clobbering iris theme fields.
    # Cupertino is a real-file copy (not a symlink): Obsidian reads themes from
    # inside the vault and the vault syncs via Syncthing, where symlinks are fragile.
    # Bump `rev` + `hash` in cupertinoTheme to update (upstream: svnaxis/obsidian-cupertino).
    # One failed command under set -e aborts the entire home-manager activation,
    # so only scaffold once the vault exists and only merge when Obsidian has
    # actually created appearance.json.
    home.activation.syncObsidianVaultConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -euo pipefail
      vault=${lib.escapeShellArg vaultObsidian}
      fonts_dir="$vault/fonts"
      appearance="$vault/appearance.json"
      cmu_src=${lib.escapeShellArg "${cmuFonts}/share/fonts/opentype"}
      cupertino_src=${lib.escapeShellArg "${cupertinoTheme}"}

      if [ -d "$vault" ]; then
        mkdir -p "$fonts_dir" "$vault/snippets" "$vault/plugins/custom-font-loader" "$vault/themes/Cupertino"

        # Copy CMU Serif fonts for the vault fonts folder
        if [ -f "$cmu_src/cmunrm.otf" ]; then
          cp -f "$cmu_src/cmunrm.otf" "$fonts_dir/CMU-Serif.otf"
        fi
        if [ -f "$cmu_src/cmunti.otf" ]; then
          cp -f "$cmu_src/cmunti.otf" "$fonts_dir/CMU-Serif-Italic.otf"
        fi
        if [ -f "$cmu_src/cmunbx.otf" ]; then
          cp -f "$cmu_src/cmunbx.otf" "$fonts_dir/CMU-Serif-Bold.otf"
        fi
        if [ -f "$cmu_src/cmunbi.otf" ]; then
          cp -f "$cmu_src/cmunbi.otf" "$fonts_dir/CMU-Serif-BoldItalic.otf"
        fi
        chmod u+w "$fonts_dir"/CMU-Serif*.otf 2>/dev/null || true

        # Clean up legacy Newsreader font files and cached CSS
        rm -f "$fonts_dir"/Newsreader*.ttf
        rm -f "$vault/plugins/custom-font-loader"/newsreader*.css
        rm -f "$vault/plugins/custom-font-loader"/cmu*.css

        # Install the Cupertino theme files (real copies, writable for Obsidian)
        cp -f "$cupertino_src/theme.css" "$vault/themes/Cupertino/theme.css"
        cp -f "$cupertino_src/manifest.json" "$vault/themes/Cupertino/manifest.json"
        chmod u+w "$vault/themes/Cupertino/theme.css" "$vault/themes/Cupertino/manifest.json" 2>/dev/null || true

        if [ -f "$appearance" ]; then
          ${pkgs.jq}/bin/jq --indent 2 '
            .textFontFamily = "CMU Serif"
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
