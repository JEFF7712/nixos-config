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
      meta = builtins.fromJSON (pf."meta.json" or "null");
      self = meta.selfThemed or false;
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
    if pf ? "meta.json" == false then
      builtins.throw "profile '${name}': no meta.json rendered"
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
