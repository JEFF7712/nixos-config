#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

config_home="$tmpdir/config"
profiles_dir="$tmpdir/profiles"
profile_dir="$profiles_dir/tinted"
comfy_dir="$config_home/spicetify/Themes/Comfy"
mkdir -p "$profile_dir" "$comfy_dir"

cat > "$profile_dir/quickshell-theme.json" <<'EOF'
{"barHeight": 34}
EOF

cat > "$comfy_dir/color.ini" <<'EOF'
[Comfy]
text = FFFFFF
main = 23283D
EOF

cat <<'EOF' | python3 "$REPO_ROOT/home/scripts/iris-render.py" \
  --config-home "$config_home" \
  --profiles-dir "$profiles_dir" \
  --profile-dir "$profile_dir"
{
  "fg": "#f7f2ee",
  "bg": "#14100f",
  "surface": "#261d1a",
  "dim": "#9f8d84",
  "accent": "#d8915f",
  "red": "#e17a76",
  "green": "#8ac083",
  "yellow": "#d8bd70",
  "syntax_keyword": "#c792ea",
  "syntax_func": "#80cbc4"
}
EOF

assert_contains() {
  local needle="$1" file="$2" label="$3"

  if ! grep -Fqx "$needle" "$file"; then
    printf 'FAIL: %s\nmissing: %s\nfile:\n' "$label" "$needle" >&2
    cat "$file" >&2
    exit 1
  fi
}

color_ini="$comfy_dir/color.ini"
assert_contains "[Comfy]" "$color_ini" "existing Comfy scheme is preserved"
assert_contains "[tinted]" "$color_ini" "tinted scheme is generated"
assert_contains "main               = 14100f" "$color_ini" "main uses iris background"
assert_contains "card               = 261d1a" "$color_ini" "card uses iris surface"
assert_contains "button             = d8915f" "$color_ini" "button uses iris accent"
assert_contains "progress-fg        = d8915f" "$color_ini" "progress uses iris accent"
