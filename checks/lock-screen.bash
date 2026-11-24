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
  "capabilities": { "wallpaperTheming": false },
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
printf 'spawned\n' >> "$HYPRLOCK_CONFIG_COPY.spawned"
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
cat > "$bin_dir/jq" <<'EOF'
#!/usr/bin/env bash
exec "$REAL_JQ" "$@"
EOF
cat > "$bin_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
if [ "${MOCK_HYPRLOCK_RUNNING:-0}" = "1" ] && [ "$1 $2" = "-x hyprlock" ]; then
  exit 0
fi
exit 1
EOF
# folio-shell is "active" only when MOCK_FOLIO is set. MainPID changes after
# MOCK_FOLIO_RESTART_AFTER lock-state polls, simulating a crash and restart.
cat > "$bin_dir/systemctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"is-active --quiet folio-shell.service"*) [ -n "${MOCK_FOLIO:-}" ] ;;
  *"show -p MainPID --value folio-shell.service"*)
    polls=$(cat "$MOCK_FOLIO_DIR/polls" 2>/dev/null || echo 0)
    if [ -n "${MOCK_FOLIO_RESTART_AFTER:-}" ] && [ "$polls" -ge "$MOCK_FOLIO_RESTART_AFTER" ]; then
      echo 200
    else
      echo 100
    fi
    ;;
  *) exit 0 ;;
esac
EOF
# Lock state walks MOCK_FOLIO_STATES (space separated), repeating the last.
cat > "$bin_dir/quickshell" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"call shell lock"*) echo lock >> "$MOCK_FOLIO_DIR/calls" ;;
  *"call lock state"*)
    polls=$(cat "$MOCK_FOLIO_DIR/polls" 2>/dev/null || echo 0)
    read -r -a states <<< "$MOCK_FOLIO_STATES"
    index=$((polls < ${#states[@]} ? polls : ${#states[@]} - 1))
    echo $((polls + 1)) > "$MOCK_FOLIO_DIR/polls"
    echo "${states[$index]}"
    ;;
esac
EOF
chmod +x "$bin_dir/hyprlock" "$bin_dir/jq" "$bin_dir/pgrep" "$bin_dir/systemctl" "$bin_dir/quickshell"

real_jq=$(command -v jq)
config_copy="$tmpdir/hyprlock.conf"

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
assert_contains '$mono_font = Try Font Mono' "$generated" "password field uses the profile mono font"
assert_contains 'color = rgb(' "$generated" "lock background has a solid fallback if the image texture fails"

printf '{"fg":"#112233","flatMode":"true"}\n' > "$profile_dir/quickshell-theme-light.json"
printf 'light\n' > "$profiles/active-variant"
cat > "$home/.config/hypr/profile-motion.conf" <<'EOF'
$hyprlock_fade_speed = 7
$hyprlock_dots_speed = 3
EOF

HOME="$home" XDG_CACHE_HOME="$cache_dir" PROFILES_DIR="$profiles" \
  HYPRLOCK_CONFIG_COPY="$config_copy" REAL_JQ="$real_jq" PATH="$bin_dir:$PATH" \
  "$REPO_ROOT/home/scripts/lock-screen"

generated=$(cat "$config_copy")
assert_contains '$fg = rgb(112233)' "$generated" "light variant selects quickshell-theme-light.json"
assert_contains 'animation = fadeIn, 1, 7, smooth' "$generated" "lock screen honors profile-motion.conf fade speed"
assert_contains 'rounding = 0' "$generated" "flat profile sets zero rounding on input field"

printf '{"fg":"#abcdef"}\n' > "$profiles/runtime-quickshell-theme.json"
printf 'nord\n' > "$profiles/runtime-theme-profile"
printf 'light\n' > "$profiles/runtime-theme-variant"

HOME="$home" XDG_CACHE_HOME="$cache_dir" PROFILES_DIR="$profiles" \
  HYPRLOCK_CONFIG_COPY="$config_copy" REAL_JQ="$real_jq" PATH="$bin_dir:$PATH" \
  "$REPO_ROOT/home/scripts/lock-screen"

generated=$(cat "$config_copy")
assert_contains '$fg = rgb(abcdef)' "$generated" "matching runtime-quickshell-theme.json overrides baked theme"
printf 'dark\n' > "$profiles/active-variant"

# A running hyprlock already owns the session lock: exit 0 without spawning
# a second instance (niri refuses it, the loser lingers and can stall input
# post-resume, forcing a hard power-off).
printf 'nord\n' > "$profiles/active"
rm -f "$config_copy.spawned"
HOME="$home" XDG_CACHE_HOME="$cache_dir" PROFILES_DIR="$profiles" \
  MOCK_HYPRLOCK_RUNNING=1 \
  HYPRLOCK_CONFIG_COPY="$config_copy" REAL_JQ="$real_jq" PATH="$bin_dir:$PATH" \
  "$REPO_ROOT/home/scripts/lock-screen"

assert_eq "" "$(cat "$config_copy.spawned" 2>/dev/null || true)" "second hyprlock is not spawned while one runs"

run_folio() {
  local dir="$tmpdir/folio-$1"
  rm -rf "$dir"
  mkdir -p "$dir"
  rm -f "$config_copy.spawned"
  HOME="$home" XDG_CACHE_HOME="$cache_dir" PROFILES_DIR="$profiles" \
    HYPRLOCK_CONFIG_COPY="$config_copy" REAL_JQ="$real_jq" PATH="$bin_dir:$PATH" \
    MOCK_FOLIO=1 MOCK_FOLIO_DIR="$dir" MOCK_FOLIO_STATES="$2" \
    MOCK_FOLIO_RESTART_AFTER="${3:-}" FOLIO_LOCK_POLL=0 \
    "$REPO_ROOT/home/scripts/lock-screen"
}

run_folio unlocks "unlocked pending locked locked unlocked"
assert_eq "lock" "$(cat "$tmpdir/folio-unlocks/calls")" "folio lock asks the shell to lock once"
assert_eq "no" "$([ -e "$config_copy.spawned" ] && echo yes || echo no)" "folio lock does not spawn hyprlock"

run_folio already "locked locked unlocked"
assert_eq "no" "$([ -e "$tmpdir/folio-already/calls" ] && echo yes || echo no)" "an existing folio lock is not re-requested"

run_folio never "unlocked"
assert_eq "spawned" "$(cat "$config_copy.spawned")" "hyprlock takes over when folio never confirms the lock"

run_folio crashed "unlocked locked locked locked" 3
assert_eq "spawned" "$(cat "$config_copy.spawned")" "hyprlock takes over when folio restarts while locked"

printf 'lock-screen checks passed\n'
