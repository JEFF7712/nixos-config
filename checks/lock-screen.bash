#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir" || true' EXIT

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" != "$actual" ]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_contains() {
  local needle="$1" haystack="$2" label="$3"
  if ! grep -Fq -- "$needle" <<<"$haystack"; then
    printf 'FAIL: %s\nmissing: %s\nin:\n%s\n' "$label" "$needle" "$haystack" >&2
    exit 1
  fi
}

home="$tmpdir/home"
profiles="$home/.config/desktop-profiles"
profile_dir="$profiles/nord"
bin_dir="$tmpdir/bin"
cache_dir="$home/.cache"
mkdir -p "$profile_dir" "$bin_dir" "$home/.config/waypaper" "$cache_dir"

cat > "$profile_dir/manifest.json" <<'EOF'
{
  "schemaVersion": 1,
  "name": "nord",
  "capabilities": { "selfThemed": false, "wallpaperTheming": false },
  "transition": {
    "defaultBar": "quickshell",
    "cursor": {},
    "fonts": {
      "ui": { "family": "IBM Plex Sans", "size": 11 },
      "mono": { "family": "Iosevka Nerd Font", "size": 14 }
    },
    "appearance": {}
  },
  "variants": {
    "dark": { "wallpaperDirectory": "/missing-wallpapers", "adapters": {}, "artifacts": {} }
  },
  "artifacts": {}
}
EOF
printf '{"fg":"#eceff4"}\n' > "$profile_dir/quickshell-theme.json"
printf 'nord\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"

cat > "$bin_dir/hyprlock" <<'EOF'
#!/usr/bin/env bash
config=""
while [ $# -gt 0 ]; do
  case "$1" in
    --config)
      config="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [ -n "$config" ]; then
  cp "$config" "$HYPRLOCK_CONFIG_COPY"
fi
exit 0
EOF
cat > "$bin_dir/noctalia" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$NOCTALIA_ARGV"
exit 0
EOF
cat > "$bin_dir/jq" <<'EOF'
#!/usr/bin/env bash
exec "$REAL_JQ" "$@"
EOF
chmod +x "$bin_dir/hyprlock" "$bin_dir/noctalia" "$bin_dir/jq"

real_jq=$(command -v jq)
config_copy="$tmpdir/hyprlock.conf"
noctalia_argv="$tmpdir/noctalia.argv"

HOME="$home" XDG_CACHE_HOME="$cache_dir" PROFILES_DIR="$profiles" \
  HYPRLOCK_CONFIG_COPY="$config_copy" REAL_JQ="$real_jq" PATH="$bin_dir:$PATH" \
  "$REPO_ROOT/home/scripts/lock-screen"

generated=$(cat "$config_copy")
assert_contains '$font = IBM Plex Sans' "$generated" "lock screen uses the profile UI font"
assert_contains '$mono_font = Iosevka Nerd Font' "$generated" "password field uses the profile mono font"
assert_contains 'font_family = $font' "$generated" "clock labels keep \$font"
assert_contains 'font_family = $mono_font' "$generated" "input field uses \$mono_font"

mkdir -p "$home/.config/hypr"
cat > "$home/.config/hypr/profile-font.conf" <<'EOF'
$font = Try Font UI
$mono_font = Try Font Mono
EOF

HOME="$home" XDG_CACHE_HOME="$cache_dir" PROFILES_DIR="$profiles" \
  HYPRLOCK_CONFIG_COPY="$config_copy" REAL_JQ="$real_jq" PATH="$bin_dir:$PATH" \
  "$REPO_ROOT/home/scripts/lock-screen"

generated=$(cat "$config_copy")
assert_contains '$font = Try Font UI' "$generated" "try-font override wins over the manifest UI font"
assert_contains '$mono_font = Try Font Mono' "$generated" "try-font override wins over the manifest mono font"

printf 'noctalia\n' > "$profiles/active"
mkdir -p "$profiles/noctalia"
printf '%s\n' '{"schemaVersion":1,"name":"noctalia","capabilities":{"selfThemed":true},"transition":{"defaultBar":"noctalia","cursor":{},"fonts":{},"appearance":{}},"variants":{"dark":{"wallpaperDirectory":"/x","adapters":{},"artifacts":{}}},"artifacts":{}}' \
  > "$profiles/noctalia/manifest.json"

HOME="$home" XDG_CACHE_HOME="$cache_dir" PROFILES_DIR="$profiles" \
  NOCTALIA_ARGV="$noctalia_argv" REAL_JQ="$real_jq" PATH="$bin_dir:$PATH" \
  "$REPO_ROOT/home/scripts/lock-screen"

assert_eq "msg session lock" "$(cat "$noctalia_argv")" "noctalia profile still uses noctalia lock"

printf 'lock-screen checks passed\n'
