#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

config_home="$tmpdir/config"
profiles_dir="$tmpdir/profiles"
profile_dir="$profiles_dir/clean"
mkdir -p "$config_home" "$profile_dir"

# Baked quickshell theme (as clean.nix ships it): #66/#cc alpha-prefixed ARGB
# panel colors plus a plain rawBg/accent. temperature-render must retint the
# RGB portion only and leave the alpha prefixes untouched.
cat > "$profile_dir/quickshell-theme.json" <<'EOF'
{
  "barHeight": "38",
  "fg": "#ffffff",
  "bg": "#66101010",
  "popupBg": "#cc101010",
  "rawBg": "#101010",
  "accent": "#ffffff"
}
EOF

assert_contains() {
  local needle="$1" file="$2" label="$3"

  if ! grep -Fq "$needle" "$file"; then
    printf 'FAIL: %s\nmissing: %s\nfile:\n' "$label" "$needle" >&2
    cat "$file" >&2
    exit 1
  fi
}

# Bad seed must fail fast rather than silently write bogus files.
if python3 "$REPO_ROOT/home/scripts/temperature-render.py" \
  --seed 'not-a-color' \
  --mode dark \
  --config-home "$config_home" \
  --profiles-dir "$profiles_dir" \
  --profile-dir "$profile_dir" >/dev/null 2>&1; then
  echo "FAIL: bad seed should exit non-zero" >&2
  exit 1
fi

# Cool (blue-leaning) seed: the tint must lean the near-white/near-grey
# palette toward blue without ever producing a saturated accent.
accent_out="$(python3 "$REPO_ROOT/home/scripts/temperature-render.py" \
  --seed '#3a5f8a' \
  --mode dark \
  --config-home "$config_home" \
  --profiles-dir "$profiles_dir" \
  --profile-dir "$profile_dir")"

if ! [[ "$accent_out" =~ ^#[0-9a-fA-F]{6}$ ]]; then
  printf 'FAIL: stdout accent is not an opaque #rrggbb hex\ngot: %s\n' "$accent_out" >&2
  exit 1
fi

accent_out="${accent_out,,}"
r=$((16#${accent_out:1:2}))
g=$((16#${accent_out:3:2}))
b=$((16#${accent_out:5:2}))

if [ "$r" -lt 240 ] || [ "$g" -lt 240 ] || [ "$b" -lt 240 ]; then
  printf 'FAIL: accent %s is not near-white (no saturated accent allowed)\n' "$accent_out" >&2
  exit 1
fi

if [ "$b" -lt "$r" ]; then
  printf 'FAIL: accent %s should lean cool (blue >= red) for a blue seed\n' "$accent_out" >&2
  exit 1
fi

quickshell_out="$profiles_dir/runtime-quickshell-theme.json"
[ -f "$quickshell_out" ] || {
  echo "FAIL: quickshell runtime theme was not written" >&2
  exit 1
}
assert_contains '"#66' "$quickshell_out" "quickshell keeps the baked #66 alpha prefix"

gtk_out="$config_home/gtk-3.0/noctalia.css"
[ -f "$gtk_out" ] || {
  echo "FAIL: gtk-3.0 noctalia.css was not written" >&2
  exit 1
}
assert_contains 'rgba(' "$gtk_out" "gtk uses glass rgba() colors"
[ -f "$config_home/gtk-4.0/noctalia.css" ] || {
  echo "FAIL: gtk-4.0 noctalia.css was not written" >&2
  exit 1
}

kitty_bg_line="$(grep '^background ' "$config_home/kitty/colors.conf")"
kitty_bg_hex="${kitty_bg_line##* }"
kitty_bg_hex="${kitty_bg_hex,,}"
kr=$((16#${kitty_bg_hex:1:2}))
kg=$((16#${kitty_bg_hex:3:2}))
kb=$((16#${kitty_bg_hex:5:2}))
if [ "$kb" -lt "$kr" ]; then
  printf 'FAIL: kitty background %s should lean cool (blue >= red) for a blue seed\n' "$kitty_bg_hex" >&2
  exit 1
fi

for f in \
  "$config_home/qt6ct/colors/noctalia.conf" \
  "$config_home/qt5ct/colors/noctalia.conf" \
  "$profiles_dir/runtime-cava-colors" \
  "$config_home/btop/themes/profile.theme" \
  "$config_home/hypr/profile-colors.conf" \
  "$config_home/tmux/profile-colors.conf" \
  "$config_home/fish/conf.d/matugen_theme.fish" \
  "$config_home/starship_matugen.toml" \
  "$config_home/rofi/profile-switcher.rasi"; do
  [ -s "$f" ] || {
    printf 'FAIL: expected destination missing or empty: %s\n' "$f" >&2
    exit 1
  }
done

echo "OK: temperature-render.bash"
