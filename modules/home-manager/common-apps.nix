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
  # desktop-profile switcher swap the Comfy color scheme per profile (see
  # apply_spicetify_theme in home/scripts/profile-common). spicetify-nix is
  # still the source of the Comfy theme and the extension files.
  comfyTheme = spicePkgs.themes.comfy;
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

    xdg.configFile."vesktop/themes/minimal.theme.css".source =
      config.lib.file.mkOutOfStoreSymlink "${config.repoPath}/home/configs/vesktop/themes/minimal.theme.css";

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
      run rm -rf "$SPICETIFY_CONFIG/Themes/Comfy"
      run cp -r "${comfyTheme.src}" "$SPICETIFY_CONFIG/Themes/Comfy"
      run chmod -R u+w "$SPICETIFY_CONFIG/Themes/Comfy"
      # Comfy's user.css only @imports its stylesheet from comfy-themes.github.io,
      # which Spotify's renderer CSP blocks — the theme flashes then reverts to
      # default. Inject the bundled app.css directly so it's self-contained.
      run cp "$SPICETIFY_CONFIG/Themes/Comfy/app.css" "$SPICETIFY_CONFIG/Themes/Comfy/user.css"
      ${lib.concatMapStringsSep "\n      " (
        e: ''run install -m644 "${e.src}/${e.name}" "$SPICETIFY_CONFIG/Extensions/${e.name}"''
      ) spiceExtensions}

      run ${spicetifyBin} config \
        spotify_path "$state/app" \
        prefs_path "$HOME/.config/spotify/prefs" \
        current_theme Comfy \
        color_scheme Comfy \
        inject_css 1 replace_colors 1 overwrite_assets 1 \
        inject_theme_js 0 \
        extensions "${extList}" > /dev/null 2>&1 || true

      if [ -n "''${fresh:-}" ] || [ -e "$state/app/Apps/xpui.spa" ]; then
        run ${spicetifyBin} -n backup apply > /dev/null 2>&1 || true
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
