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

  # Mutable spicetify. spicetify-nix bakes the theme into a read-only store
  # Spotify that can't be re-themed at runtime; instead we keep a writable copy
  # of Spotify under $HOME that `spicetify apply` can patch live, letting the
  # desktop-profile switcher swap the theme + color scheme per profile (see
  # apply_spicetify_theme in home/scripts/profile-common). spicetify-nix is
  # still the source of the themes and the extension files.
  #
  # Each profile picks a (theme, scheme, js) triple in runtime-defaults.nix.
  # Themes are installed generically: theme.js is staged as theme.script.js so
  # inject_theme_js can load it per-theme (Dribbblish needs it; Comfy's would
  # fight our scheme control, so its profiles set js=0), a remote-@import
  # user.css is replaced with the bundled app.css (Comfy's is CSP-blocked), and
  # any additionalCss is appended.
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
        # A theme that pulls assets from a CDN (Spotify's CSP blocks them) can
        # set `assets` (a dir to vendor) + `rewrite` (the URL prefix to strip),
        # and `patch` for a trailing user.css fixup. See git history for Bloom.
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
  # Launches the writable, spiced copy instead of the read-only store Spotify.
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
      pywalfox-native
      pkgs-stable.zoom
      pkgs-stable.calibre
      zed-editor
      spotify-player
      spicetify-cli
      spotifyLauncher
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
      };
      defaultApplications = {
        "inode/directory" = "thunar.desktop";
        "application/x-directory" = "thunar.desktop";
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/about" = "firefox.desktop";
        "x-scheme-handler/unknown" = "firefox.desktop";
        "application/pdf" = "firefox.desktop";
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

    xdg.configFile."vesktop/themes/sharp.theme.css".source =
      config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/vesktop/themes/sharp.theme.css";

    home.file.".mozilla/firefox/09longn9.default-release/user.js".text = ''
      user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
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

    # Build/refresh the writable Spotify copy and its spicetify config. The
    # 300 MB copy is only rebuilt when the Spotify store path changes (stamp
    # check); `backup apply` runs once per fresh copy. Runtime color-scheme
    # switching is handled by apply_spicetify_theme in switch-profile.
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
        # Drop any stale backup/version record (e.g. from a prior Spotify
        # version or the old spicetify-nix setup) so `backup apply` re-records
        # the version of the fresh copy; a mismatch otherwise blocks every
        # subsequent `spicetify apply`.
        run rm -rf "$SPICETIFY_CONFIG/Backup" "$SPICETIFY_CONFIG/config-xpui.ini"
        fresh=1
      fi

      run mkdir -p "$SPICETIFY_CONFIG/Themes" "$SPICETIFY_CONFIG/Extensions" "$HOME/.config/spotify"
      ${lib.concatMapStringsSep "\n" (t: ''
        td="$SPICETIFY_CONFIG/Themes/${t.name}"
        # Prior runs may have left read-only store copies (e.g. vendored
        # assets); make the tree writable so rm -rf can always replace it.
        chmod -R u+w "$td" 2>/dev/null || true
        run rm -rf "$td"
        run cp -r "${t.src}" "$td"
        run chmod -R u+w "$td"
        # A user.css that only @imports a remote stylesheet (e.g. Comfy ->
        # github.io) is blocked by Spotify's CSP; swap in the bundled app.css.
        if [ -f "$td/app.css" ] && grep -qE 'import +url\(.*https?:' "$td/user.css" 2>/dev/null; then
          run cp "$td/app.css" "$td/user.css"
        fi
        # Stage the theme's JS as theme.script.js so inject_theme_js loads it
        # only when this theme is active (Dribbblish requires it).
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

      # Apply the active desktop profile's spicetify pick (theme/scheme/js) so a
      # rebuild or Spotify update doesn't leave Spotify on a stale/default theme
      # until the next manual profile switch. Falls back to Comfy.
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

      # --no-restart so a rebuild never interrupts a running Spotify; the patched
      # xpui is picked up on its next launch.
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
        ];
      };
    };

    xdg.configFile."Code/User/settings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/vscode/settings.json";
      force = true;
    };
  };
}
