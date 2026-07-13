#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

export PROFILES_DIR="$tmpdir/profiles"
profile_dir="$PROFILES_DIR/sharp"
mkdir -p "$profile_dir"

for file in niri.kdl niri-focus.kdl dark.css light.css quickshell-dark.json quickshell-light.json; do
  printf 'fixture\n' > "$profile_dir/$file"
done

cat > "$profile_dir/manifest.json" <<'EOF'
{
  "schemaVersion": 1,
  "name": "sharp",
  "capabilities": { "selfThemed": false, "wallpaperTheming": true },
  "transition": { "defaultBar": "quickshell", "cursor": {}, "fonts": {}, "appearance": {} },
  "variants": {
    "dark": {
      "wallpaperDirectory": "/wallpapers/dark",
      "adapters": { "spicetify": { "theme": "Comfy", "scheme": "sharp", "js": 0 } },
      "artifacts": { "gtk3": "dark.css" }
    },
    "light": {
      "wallpaperDirectory": "/wallpapers/light",
      "adapters": {},
      "artifacts": { "gtk3": "light.css" }
    }
  },
  "artifacts": {
    "niri": { "default": "niri.kdl", "focus": "niri-focus.kdl" },
    "quickshell": { "dark": "quickshell-dark.json", "light": "quickshell-light.json" }
  }
}
EOF

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" != "$actual" ]; then
    printf 'FAIL: %s\nexpected: %s\nactual: %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

expect_invalid() {
  local label="$1"
  if profile_manifest_validate sharp dark >/dev/null 2>&1; then
    printf 'FAIL: accepted %s\n' "$label" >&2
    exit 1
  fi
}

# shellcheck source=/dev/null
. "$repo_root/home/scripts/profile-manifest"

profile_manifest_validate sharp dark
profile_manifest_has_variant sharp light
assert_eq quickshell "$(profile_manifest_bar sharp)" "default bar"
assert_eq false "$(profile_manifest_capability sharp selfThemed)" "boolean capability"
assert_eq /wallpapers/light "$(profile_manifest_wallpaper_dir sharp light)" "variant wallpaper"
assert_eq "$profile_dir/niri.kdl" "$(profile_manifest_artifact sharp dark niri.default)" "shared artifact"
assert_eq "$profile_dir/light.css" "$(profile_manifest_artifact sharp light gtk3)" "variant artifact"
assert_eq Comfy "$(profile_manifest_adapter sharp dark spicetify | jq -r .theme)" "adapter data"
assert_eq $'dark\nlight' "$(profile_manifest_variants sharp)" "variant list"

cp "$profile_dir/manifest.json" "$tmpdir/valid.json"

jq 'del(.schemaVersion)' "$tmpdir/valid.json" > "$profile_dir/manifest.json"
expect_invalid "missing schema version"
jq '.schemaVersion = "1"' "$tmpdir/valid.json" > "$profile_dir/manifest.json"
expect_invalid "non-integer schema version"
jq '.schemaVersion = 2' "$tmpdir/valid.json" > "$profile_dir/manifest.json"
expect_invalid "unsupported schema version"
jq '.name = "other"' "$tmpdir/valid.json" > "$profile_dir/manifest.json"
expect_invalid "profile name mismatch"
jq 'del(.variants.dark)' "$tmpdir/valid.json" > "$profile_dir/manifest.json"
expect_invalid "missing dark variant"
jq '.variants.dark.artifacts.gtk3 = "/tmp/escape"' "$tmpdir/valid.json" > "$profile_dir/manifest.json"
expect_invalid "absolute artifact path"
jq '.variants.dark.artifacts.gtk3 = "../escape"' "$tmpdir/valid.json" > "$profile_dir/manifest.json"
expect_invalid "parent-traversing artifact path"
jq '.variants.dark.artifacts.gtk3 = "missing.css"' "$tmpdir/valid.json" > "$profile_dir/manifest.json"
expect_invalid "missing artifact"
printf '{\n' > "$profile_dir/manifest.json"
expect_invalid "invalid JSON"
rm "$profile_dir/manifest.json"
expect_invalid "missing manifest"

printf 'profile manifest checks passed\n'
