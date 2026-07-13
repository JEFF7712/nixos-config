# Desktop-profile render validator. Applied to a home-manager `home.file`
# attrset (`nix eval ... --apply 'import ./checks/profiles.nix'`). For every
# `.config/desktop-profiles/<name>/` file it:
#   - parses meta.json (fromJSON throws on malformed JSON),
#   - for non-self-themed profiles, fails if any rendered color file is empty
#     (an empty file means a palette role resolved to null — a broken profile).
# Returns a JSON summary on success; throws with the offending profile on
# failure, so `nix eval` exits non-zero in CI / `just check`.
files:
let
  colorFiles = [
    "gtk-3.0.css"
    "gtk-4.0.css"
    "qt6ct.conf"
    "kitty-colors.conf"
    "fish-theme.fish"
    "starship.toml"
    "rofi-theme.rasi"
    "btop.theme"
    "tmux-colors.conf"
    "hyprlock-colors.conf"
    "cava-colors"
    "gtk-3.0-light.css"
    "gtk-4.0-light.css"
    "qt6ct-light.conf"
    "kitty-colors-light.conf"
    "fish-theme-light.fish"
    "starship-light.toml"
    "rofi-theme-light.rasi"
    "btop-light.theme"
    "tmux-colors-light.conf"
    "hyprlock-colors-light.conf"
    "cava-colors-light"
  ];

  vicinaeThemeFiles = [
    "vicinae-theme-dark.toml"
    "vicinae-theme-light.toml"
  ];

  entries = builtins.filter (x: x != null) (
    map (
      k:
      let
        m = builtins.match "\\.config/desktop-profiles/([^/]+)/(.+)" k;
      in
      if m == null then
        null
      else
        {
          name = builtins.elemAt m 0;
          file = builtins.elemAt m 1;
          text = files.${k}.text or "";
        }
    ) (builtins.attrNames files)
  );

  byProfile = builtins.foldl' (
    acc: e:
    acc
    // {
      ${e.name} = (acc.${e.name} or { }) // {
        ${e.file} = e.text;
      };
    }
  ) { } entries;

  checkProfile =
    name: pf:
    let
      stringsOf =
        value:
        if builtins.isString value then
          [ value ]
        else if builtins.isAttrs value then
          builtins.concatLists (map stringsOf (builtins.attrValues value))
        else
          [ ];
      manifestText =
        pf."manifest.json" or (builtins.throw "profile '${name}': no manifest.json rendered");
      manifest = builtins.fromJSON manifestText;
      self = manifest.capabilities.selfThemed or false;
      variants = manifest.variants or { };
      artifactRefs =
        stringsOf (manifest.artifacts or { })
        ++ builtins.concatLists (
          map (variant: stringsOf (variant.artifacts or { })) (builtins.attrValues variants)
        );
      unsafeArtifacts = builtins.filter (
        path: builtins.substring 0 1 path == "/" || builtins.match "(^|.*/)\.\.(/.*|$)" path != null
      ) artifactRefs;
      missingArtifacts = builtins.filter (path: !(pf ? ${path})) artifactRefs;
      legacy = builtins.filter (file: pf ? ${file}) [
        "meta.json"
        "runtime.json"
        "wallpaper-dir"
        "wallpaper-dir-light"
      ];
      empties = builtins.filter (f: (pf ? ${f}) && (builtins.stringLength pf.${f} == 0)) colorFiles;
      missingVicinaeThemes = builtins.filter (f: !(pf ? ${f})) vicinaeThemeFiles;
      vicinaeThemeBad =
        f:
        !(
          builtins.match ".*meta.*name = \"${name}.*variant = \".*colors.core.*accent = \".*" pf.${f} != null
        );
      badVicinaeThemes = builtins.filter (f: (pf ? ${f}) && vicinaeThemeBad f) vicinaeThemeFiles;
      niriOverrides = pf."niri-overrides.kdl" or "";
      niriFocus = pf."niri-overrides-focus.kdl" or "";
    in
    if manifest.schemaVersion or null != 1 then
      builtins.throw "profile '${name}': unsupported manifest schema version"
    else if manifest.name or null != name then
      builtins.throw "profile '${name}': manifest name mismatch"
    else if !(builtins.isAttrs (manifest.capabilities or null)) then
      builtins.throw "profile '${name}': manifest capabilities must be an object"
    else if !(builtins.isAttrs (manifest.transition or null)) then
      builtins.throw "profile '${name}': manifest transition must be an object"
    else if !(builtins.isAttrs variants) || !(variants ? dark) then
      builtins.throw "profile '${name}': manifest has no dark variant"
    else if unsafeArtifacts != [ ] then
      builtins.throw "profile '${name}': unsafe artifact paths: ${builtins.concatStringsSep ", " unsafeArtifacts}"
    else if missingArtifacts != [ ] then
      builtins.throw "profile '${name}': missing artifact files: ${builtins.concatStringsSep ", " missingArtifacts}"
    else if
      manifest.transition.defaultBar or null == "quickshell" && !(manifest.artifacts ? quickshell.dark)
    then
      builtins.throw "profile '${name}': quickshell bar has no dark theme artifact"
    else if
      manifest.transition.defaultBar or null == "waybar" && !(manifest.artifacts ? waybar.config)
    then
      builtins.throw "profile '${name}': waybar has no config artifact"
    else if legacy != [ ] then
      builtins.throw "profile '${name}': legacy artifacts rendered: ${builtins.concatStringsSep ", " legacy}"
    else if !(builtins.match ".*animations[[:space:]]*\\{.*" niriOverrides != null) then
      builtins.throw "profile '${name}': niri-overrides.kdl has no animations block"
    else if !(builtins.match ".*animations[[:space:]]*\\{[[:space:]]*off.*" niriFocus != null) then
      builtins.throw "profile '${name}': niri-overrides-focus.kdl does not disable animations"
    else if (!self) && empties != [ ] then
      builtins.throw "profile '${name}': empty color files: ${builtins.concatStringsSep ", " empties}"
    else if missingVicinaeThemes != [ ] then
      builtins.throw "profile '${name}': missing Vicinae theme files: ${builtins.concatStringsSep ", " missingVicinaeThemes}"
    else if badVicinaeThemes != [ ] then
      builtins.throw "profile '${name}': malformed Vicinae theme files: ${builtins.concatStringsSep ", " badVicinaeThemes}"
    else
      true;

  names = builtins.attrNames byProfile;

  slideProfiles = [
    "gruvbox"
    "nord"
    "sharp"
  ];

  checkSlideProfile =
    name:
    let
      pf = byProfile.${name};
      theme = builtins.fromJSON (pf."quickshell-theme.json" or "{}");
      lightTheme = builtins.fromJSON (pf."quickshell-theme-light.json" or "{}");
      hasLightTheme = pf ? "quickshell-theme-light.json";
    in
    if theme.moduleAnimationStyle or "" != "slide" then
      builtins.throw "profile '${name}': quickshell-theme.json does not set moduleAnimationStyle=slide"
    else if hasLightTheme && lightTheme.moduleAnimationStyle or "" != "slide" then
      builtins.throw "profile '${name}': quickshell-theme-light.json does not set moduleAnimationStyle=slide"
    else if theme.popupAttachToBar or "" != "true" then
      builtins.throw "profile '${name}': quickshell-theme.json does not set popupAttachToBar=true"
    else if hasLightTheme && lightTheme.popupAttachToBar or "" != "true" then
      builtins.throw "profile '${name}': quickshell-theme-light.json does not set popupAttachToBar=true"
    else
      true;

  ok = builtins.all (n: checkProfile n byProfile.${n}) names;
  slideOk = builtins.all checkSlideProfile slideProfiles;
in
{
  ok = ok && slideOk;
  inherit names;
  count = builtins.length names;
}
