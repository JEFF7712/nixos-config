#!/usr/bin/env bash
# Spotifast profile theming: spotifast-apply seeds/selects/reloads, and the
# matugen templates render valid palettes.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

export HOME="$tmpdir/home"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$XDG_CONFIG_HOME/desktop-profiles" "$XDG_CONFIG_HOME/spotifast/themes"
mkdir -p "$tmpdir/bin"
export PATH="$tmpdir/bin:$PATH"

cat > "$tmpdir/bin/spotifast" <<EOF
#!/usr/bin/env bash
printf 'spotifast %s\n' "\$*" >> "$tmpdir/commands.log"
EOF
chmod +x "$tmpdir/bin/spotifast"

echo dark > "$XDG_CONFIG_HOME/desktop-profiles/active-variant"

# Baked palette with a stale light base: the normalizer must flip it to dark.
cat > "$tmpdir/baked.json" <<'EOF'
{
  "base": "light",
  "colors": {
    "window": "#101010",
    "panel": "#181818",
    "surface": "#181818",
    "surface_hover": "#282828",
    "surface_active": "#383838",
    "outline": "#282828",
    "text": "#f2f2f2",
    "secondary": "#c8c8c8",
    "dim": "#8a8a8a",
    "accent": "#e0e0e0",
    "on_accent": "#101010",
    "danger": "#ff6b6b",
    "warning": "#e0e0e0"
  }
}
EOF

cat > "$XDG_CONFIG_HOME/spotifast/settings.json" <<'EOF'
{
  "theme": "system",
  "custom_theme": null,
  "volume": 65535
}
EOF

"$REPO_ROOT/home/scripts/spotifast-apply" "$tmpdir/baked.json"

target="$XDG_CONFIG_HOME/spotifast/themes/profile.json"
python3 - "$target" <<'PY'
import json
import sys

theme = json.load(open(sys.argv[1]))
assert theme["base"] == "dark", theme
assert theme["colors"]["window"] == "#101010", theme
assert theme["colors"]["accent"] == "#e0e0e0", theme
assert theme["colors"]["accent_hover"] == "#e4e4e4", theme
PY

python3 - "$XDG_CONFIG_HOME/spotifast/settings.json" <<'PY'
import json
import sys

settings = json.load(open(sys.argv[1]))
assert settings["custom_theme"] == "profile.json", settings
assert settings["theme"] == "system", settings
assert settings["volume"] == 65535, settings
PY

grep -Fqx "spotifast reload-themes" "$tmpdir/commands.log" || {
  echo "FAIL: spotifast-apply did not reload themes" >&2
  exit 1
}

# Second run without a seed is idempotent and still reloads.
: > "$tmpdir/commands.log"
"$REPO_ROOT/home/scripts/spotifast-apply"
grep -Fqx "spotifast reload-themes" "$tmpdir/commands.log" || {
  echo "FAIL: seedless spotifast-apply did not reload themes" >&2
  exit 1
}

# An invalid managed palette leaves the selection alone and exits zero.
printf 'not json\n' > "$target"
"$REPO_ROOT/home/scripts/spotifast-apply"
python3 - "$XDG_CONFIG_HOME/spotifast/settings.json" <<'PY'
import json
import sys

assert json.load(open(sys.argv[1]))["custom_theme"] == "profile.json"
PY

# A missing settings.json is never fabricated; the app owns it.
rm "$XDG_CONFIG_HOME/spotifast/settings.json"
rm -f "$target"
"$REPO_ROOT/home/scripts/spotifast-apply" "$tmpdir/baked.json"
[ ! -e "$XDG_CONFIG_HOME/spotifast/settings.json" ] || {
  echo "FAIL: spotifast-apply fabricated settings.json" >&2
  exit 1
}

# Matugen templates render valid palettes in both modes.
if ! command -v matugen >/dev/null 2>&1; then
  echo "FAIL: matugen is required for checks/spotifast-theme.bash" >&2
  exit 1
fi

for templates in templates templates-sharp; do
  cfg="$tmpdir/matugen-$templates.toml"
  cat > "$cfg" <<EOF
[config]

[templates.spotifast]
input_path = "$REPO_ROOT/home/configs/matugen/$templates/spotifast.json"
output_path = "$tmpdir/spotifast-$templates.json"
EOF
  for mode in dark light; do
    if ! matugen color hex "#fe9004" --mode "$mode" --type scheme-tonal-spot \
      -c "$cfg" --quiet; then
      printf 'FAIL: matugen %s %s render failed\n' "$templates" "$mode" >&2
      exit 1
    fi
    python3 - "$tmpdir/spotifast-$templates.json" <<'PY'
import json
import re
import sys

theme = json.load(open(sys.argv[1]))
assert set(theme) == {"base", "colors"}, set(theme)
colors = theme["colors"]
assert len(colors) == 13, len(colors)
for name, value in colors.items():
    assert re.fullmatch(r"#[0-9a-fA-F]{6}", value), (name, value)
PY
  done
done

echo "OK: spotifast-theme.bash"
