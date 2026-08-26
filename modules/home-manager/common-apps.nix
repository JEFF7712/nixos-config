{
  pkgs,
  pkgs-stable,
  lib,
  config,
  inputs,
  ...
}:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Writable $HOME Spotify copy: spicetify-nix's store Spotify can't be
  # re-themed at runtime. Theme/scheme/js picks live in runtime-defaults.nix.
  spiceThemes =
    map
      (e: {
        inherit (e.theme) name src;
        addCss =
          let
            c = e.theme.additionalCss or "";
          in
          if c != "" then pkgs.writeText "${e.theme.name}-additional.css" c else null;
        assets = e.assets or null;
        rewrite = e.rewrite or null;
        patch =
          let
            p = e.patch or "";
          in
          if p != "" then pkgs.writeText "${e.theme.name}-patch.css" p else null;
      })
      [
        { theme = spicePkgs.themes.comfy; }
        { theme = spicePkgs.themes.catppuccin; }
        { theme = spicePkgs.themes.sleek; }
        { theme = spicePkgs.themes.dribbblish; }
        # CDN themes: set `assets` + `rewrite` (URL prefix to strip) + optional `patch`.
      ];
  spiceExtensions = with spicePkgs.extensions; [
    fullAppDisplay
    shuffle
    hidePodcasts
    adblock
    beautiful-lyrics
    CoverAmbience
  ];
  spiceState = ".local/share/spotify-spiced";
  spicetifyBin = "${pkgs.spicetify-cli}/bin/spicetify";
  extList = builtins.concatStringsSep "|" (map (e: e.name) spiceExtensions);
  spotifyLauncher = pkgs.writeShellScriptBin "spotify" ''
    exec "$HOME/${spiceState}/app/spotify" "$@"
  '';
in
{
  options.common-apps.enable = lib.mkEnableOption "common-apps";
  config = lib.mkIf config.common-apps.enable {

    home.packages = with pkgs; [
      networkmanagerapplet
      vesktop
      pkgs-stable.zoom
      pkgs-stable.calibre
      zed-editor
      spotify-player
      spicetify-cli
      spotifyLauncher
      zathura
    ];

    programs.firefox = {
      enable = true;
      configPath = ".mozilla/firefox";
      profiles."09longn9.default-release" = { };
    };

    xdg.mimeApps = {
      enable = true;
      associations.added = {
        "inode/directory" = [ "thunar.desktop" ];
        "application/x-directory" = [ "thunar.desktop" ];
        "application/pdf" = [
          "org.pwmt.zathura.desktop"
          "firefox.desktop"
        ];
      };
      defaultApplications = {
        "inode/directory" = "thunar.desktop";
        "application/x-directory" = "thunar.desktop";
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/about" = "firefox.desktop";
        "x-scheme-handler/unknown" = "firefox.desktop";
        "application/pdf" = "org.pwmt.zathura.desktop";
        "image/jpeg" = "firefox.desktop";
        "image/png" = "firefox.desktop";
        "image/gif" = "firefox.desktop";
        "image/webp" = "firefox.desktop";
        "image/svg+xml" = "firefox.desktop";
      };
      associations.removed = {
        "inode/directory" = [
          "org.gnome.Nautilus.desktop"
          "nautilus.desktop"
          "org.kde.dolphin.desktop"
          "dolphin.desktop"
          "nemo.desktop"
          "pcmanfm.desktop"
          "caja.desktop"
        ];
        "application/x-directory" = [
          "org.gnome.Nautilus.desktop"
          "nautilus.desktop"
          "org.kde.dolphin.desktop"
          "dolphin.desktop"
          "nemo.desktop"
          "pcmanfm.desktop"
          "caja.desktop"
        ];
      };
    };

    home.sessionVariables = {
      BROWSER = "firefox";
    };

    xdg.configFile."zathura/zathurarc".source =
      config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/zathura/zathurarc";

    xdg.configFile."vesktop/themes/sharp.theme.css".source =
      config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/vesktop/themes/sharp.theme.css";

    home.file.".mozilla/firefox/09longn9.default-release/user.js".text = ''
      user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
      // Ctrl+Alt+R in Browser Console restarts Firefox with session restore
      // (userChrome.css is only parsed at startup).
      user_pref("devtools.chrome.enabled", true);
      user_pref("devtools.debugger.remote-enabled", true);
    '';

    xdg.desktopEntries.spotify = {
      name = "Spotify";
      genericName = "Music Player";
      exec = "spotify %U";
      icon = "${pkgs.spotify}/share/icons/hicolor/512x512/apps/spotify-client.png";
      terminal = false;
      type = "Application";
      categories = [
        "Audio"
        "Music"
        "Player"
        "AudioVideo"
      ];
      mimeType = [ "x-scheme-handler/spotify" ];
      settings.StartupWMClass = "spotify";
    };

    # Rebuild the writable Spotify copy when the store path changes (stamp).
    home.activation.spicetifyMutable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export SPICETIFY_CONFIG="$HOME/.config/spicetify"
      state="$HOME/${spiceState}"
      src="${pkgs.spotify}/share/spotify"
      stamp="$state/.store-path"

      if [ "$(cat "$stamp" 2>/dev/null)" != "${pkgs.spotify}" ]; then
        run rm -rf "$state/app"
        run mkdir -p "$state"
        run cp -r "$src" "$state/app"
        run chmod -R u+w "$state/app"
        run sed -i "s|$src/.spotify-wrapped|$state/app/.spotify-wrapped|g" "$state/app/spotify"
        run sh -c "echo '${pkgs.spotify}' > '$stamp'"
        # Stale Backup/version records make later `spicetify apply` fail.
        run rm -rf "$SPICETIFY_CONFIG/Backup" "$SPICETIFY_CONFIG/config-xpui.ini"
        fresh=1
      fi

      run mkdir -p "$SPICETIFY_CONFIG/Themes" "$SPICETIFY_CONFIG/Extensions" "$HOME/.config/spotify"
      ${lib.concatMapStringsSep "\n" (t: ''
        td="$SPICETIFY_CONFIG/Themes/${t.name}"
        # Vendored store copies can be read-only; chmod so rm -rf can replace them.
        chmod -R u+w "$td" 2>/dev/null || true
        run rm -rf "$td"
        run cp -r "${t.src}" "$td"
        run chmod -R u+w "$td"
        # Remote @import user.css is CSP-blocked; swap in bundled app.css.
        if [ -f "$td/app.css" ] && grep -qE 'import +url\(.*https?:' "$td/user.css" 2>/dev/null; then
          run cp "$td/app.css" "$td/user.css"
        fi
        # inject_theme_js loads theme.script.js only for the active theme.
        if [ -f "$td/theme.js" ] && [ ! -f "$td/theme.script.js" ]; then
          run cp "$td/theme.js" "$td/theme.script.js"
        fi
        ${lib.optionalString (t.addCss != null) ''run sh -c "cat '${t.addCss}' >> '$td/user.css'"''}
        ${lib.optionalString (t.assets != null) ''
          run mkdir -p "$td/assets"
          run sh -c "cp -r '${t.assets}/.' '$td/assets/'"
          run chmod -R u+w "$td/assets"
          run sed -i "s|${t.rewrite}||g" "$td/user.css"
        ''}
        ${lib.optionalString (t.patch != null) ''run sh -c "cat '${t.patch}' >> '$td/user.css'"''}
      '') spiceThemes}
      ${lib.concatMapStringsSep "\n      " (
        e: ''run install -m644 "${e.src}/${e.name}" "$SPICETIFY_CONFIG/Extensions/${e.name}"''
      ) spiceExtensions}

      run ${spicetifyBin} config \
        spotify_path "$state/app" \
        prefs_path "$HOME/.config/spotify/prefs" \
        inject_css 1 replace_colors 1 overwrite_assets 1 \
        extensions "${extList}" > /dev/null 2>&1 || true

      # Re-apply the active profile's theme so a rebuild doesn't leave Spotify stale.
      sp_active=$(cat "$HOME/.config/desktop-profiles/active" 2>/dev/null || echo "")
      sp_variant=$(cat "$HOME/.config/desktop-profiles/active-variant" 2>/dev/null || echo "dark")
      sp_theme=Comfy
      sp_scheme=Comfy
      sp_js=0
      if [ -n "$sp_active" ]; then
        sp_pick=$(${config.repoPath}/home/scripts/profile-manifest adapter \
          "$sp_active" "$sp_variant" spicetify 2>/dev/null || true)
        if [ -n "$sp_pick" ]; then
          sp_theme=$(printf '%s' "$sp_pick" | ${pkgs.jq}/bin/jq -r '.theme // "Comfy"')
          sp_scheme=$(printf '%s' "$sp_pick" | ${pkgs.jq}/bin/jq -r '.scheme // "Comfy"')
          sp_js=$(printf '%s' "$sp_pick" | ${pkgs.jq}/bin/jq -r '.js // 0')
        fi
      fi
      run ${spicetifyBin} config current_theme "$sp_theme" color_scheme "$sp_scheme" inject_theme_js "$sp_js" > /dev/null 2>&1 || true

      # -n: don't restart a running Spotify; patched xpui loads on next launch.
      if [ -n "''${fresh:-}" ] || [ -e "$state/app/Apps/xpui.spa" ]; then
        run ${spicetifyBin} -n backup apply > /dev/null 2>&1 || true
      else
        run ${spicetifyBin} -n apply > /dev/null 2>&1 || true
      fi
    '';

    programs.vscode = {
      enable = true;
      mutableExtensionsDir = true;

      profiles.default = {
        extensions = with pkgs.vscode-marketplace; [
          jnoortheen.nix-ide
          ms-python.python
          github.copilot
          hashicorp.terraform
          pjmiravalle.terraform-advanced-syntax-highlighting
          redhat.vscode-yaml
          esbenp.prettier-vscode
          kdl-org.kdl
          ms-azuretools.vscode-docker
          rust-lang.rust-analyzer
          tauri-apps.tauri-vscode
          llvm-vs-code-extensions.vscode-clangd
          ms-vscode.cmake-tools
          james-yu.latex-workshop
        ];
      };
    };

    # Cursor does not read ~/.vscode/extensions. Mirror the HM-managed
    # LaTeX Workshop install into Cursor's mutable extensions dir.
    home.file.".cursor/extensions/james-yu.latex-workshop".source =
      "${pkgs.vscode-marketplace.james-yu.latex-workshop}/share/vscode/extensions/james-yu.latex-workshop";

    xdg.configFile."Code/User/settings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/vscode/settings.json";
      force = true;
    };
  };
}
