{
  lib,
  profileFiles,
}:

let
  adapterValues =
    runtime: variant:
    lib.filterAttrs (_: value: value != null) (
      lib.mapAttrs (
        _adapter: variants:
        if builtins.isAttrs variants then variants.${variant} or variants.dark or null else null
      ) runtime
    );

  variantArtifacts = light: {
    gtk3 = if light then "gtk-3.0-light.css" else "gtk-3.0.css";
    gtk4 = if light then "gtk-4.0-light.css" else "gtk-4.0.css";
    qt6 = if light then "qt6ct-light.conf" else "qt6ct.conf";
    kitty = if light then "kitty-colors-light.conf" else "kitty-colors.conf";
    fish = if light then "fish-theme-light.fish" else "fish-theme.fish";
    starship = if light then "starship-light.toml" else "starship.toml";
    rofi = if light then "rofi-theme-light.rasi" else "rofi-theme.rasi";
    btop = if light then "btop-light.theme" else "btop.theme";
    tmux = if light then "tmux-colors-light.conf" else "tmux-colors.conf";
    hyprlock = if light then "hyprlock-colors-light.conf" else "hyprlock-colors.conf";
    cava = if light then "cava-colors-light" else "cava-colors";
    zathura = if light then "zathura-colors-light" else "zathura-colors";
    vicinae = if light then "vicinae-theme-light.toml" else "vicinae-theme-dark.toml";
  };
in
{
  compile =
    name: profile:
    let
      rendered = profileFiles.renderProfileFiles name profile;
      runtime = profileFiles.runtimeFor name profile;
      dark = {
        wallpaperDirectory = profile.wallpaperDir;
        adapters = adapterValues runtime "dark";
        artifacts = variantArtifacts false;
      };
      light = {
        wallpaperDirectory =
          if profile.wallpaperDirLight != null then profile.wallpaperDirLight else profile.wallpaperDir;
        adapters = adapterValues runtime "light";
        artifacts = variantArtifacts true;
      };
      manifest = {
        schemaVersion = 1;
        inherit name;
        capabilities = {
          inherit (profile)
            selfThemed
            wallpaperTheming
            colorEngine
            matugenScheme
            matugenContrast
            wallpaperAccentVivid
            obsidianWallpaperTheme
            ;
        };
        transition = {
          defaultBar = profile.bar;
          cursor = {
            inherit (profile.cursor) theme size;
          };
          inherit (profile) fonts appearance;
        };
        variants = {
          inherit dark;
        }
        // lib.optionalAttrs (profileFiles.hasLight profile) { inherit light; };
        artifacts = {
          niri = {
            default = "niri-overrides.kdl";
            focus = "niri-overrides-focus.kdl";
          };
        }
        // lib.optionalAttrs (profile.quickshellTheme != null || profile.quickshellThemeLight != null) {
          quickshell =
            lib.optionalAttrs (profile.quickshellTheme != null) { dark = "quickshell-theme.json"; }
            // lib.optionalAttrs (profile.quickshellThemeLight != null) {
              light = "quickshell-theme-light.json";
            };
        }
        // lib.optionalAttrs (profile.waybar.config != null) {
          waybar = {
            config = "waybar-config.jsonc";
            dark = "waybar-style.css";
          }
          // lib.optionalAttrs (profileFiles.hasLight profile) {
            light = if profile.waybarLight.style != null then "waybar-style-light.css" else "waybar-style.css";
          };
        }
        // lib.optionalAttrs (profile.makoConfig != null || profile.makoConfigLight != null) {
          mako =
            lib.optionalAttrs (profile.makoConfig != null) { dark = "mako-config"; }
            // lib.optionalAttrs (profile.makoConfigLight != null) { light = "mako-config-light"; }
            // lib.optionalAttrs (
              profileFiles.hasLight profile && profile.makoConfigLight == null && profile.makoConfig != null
            ) { light = "mako-config"; };
        };
      };
    in
    rendered
    // {
      ".config/desktop-profiles/${name}/manifest.json".text = builtins.toJSON manifest;
    };
}
