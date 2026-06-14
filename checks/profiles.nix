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
    in
    if pf ? "meta.json" == false then
      builtins.throw "profile '${name}': no meta.json rendered"
    else if (!self) && empties != [ ] then
      builtins.throw "profile '${name}': empty color files: ${builtins.concatStringsSep ", " empties}"
    else
      true;

  names = builtins.attrNames byProfile;
  ok = builtins.all (n: checkProfile n byProfile.${n}) names;
in
{
  inherit ok names;
  count = builtins.length names;
}
