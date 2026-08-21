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

leftovers="$(find "$config_home" "$profiles_dir" -name '*.tmp' -print || true)"
if [ -n "$leftovers" ]; then
  printf 'FAIL: leftover tmp files after iris-render:\n%s\n' "$leftovers" >&2
  exit 1
fi

# Incomplete palette must fail before any consumer file is written.
bad_home="$tmpdir/bad-config"
bad_profiles="$tmpdir/bad-profiles"
bad_profile_dir="$bad_profiles/tinted"
mkdir -p "$bad_profile_dir"
cat > "$bad_profile_dir/quickshell-theme.json" <<'EOF'
{"barHeight": 34}
EOF
if python3 "$REPO_ROOT/home/scripts/iris-render.py" \
  --config-home "$bad_home" \
  --profiles-dir "$bad_profiles" \
  --profile-dir "$bad_profile_dir" >/dev/null 2>&1 <<'EOF'
{
  "fg": "#f7f2ee",
  "bg": "#14100f",
  "surface": "#261d1a",
  "dim": "#9f8d84",
  "accent": "#d8915f",
  "green": "#8ac083",
  "yellow": "#d8bd70"
}
EOF
then
  echo "FAIL: incomplete palette should exit non-zero" >&2
  exit 1
fi
if [ -e "$bad_profiles/runtime-quickshell-theme.json" ]; then
  echo "FAIL: incomplete palette wrote the quickshell theme" >&2
  exit 1
fi
if [ -e "$bad_home/kitty/colors.conf" ]; then
  echo "FAIL: incomplete palette wrote kitty colors" >&2
  exit 1
fi

# Corrupt Obsidian appearance.json must not be replaced with a stub.
vault="$tmpdir/obsidian-vault"
mkdir -p "$vault"
printf 'NOT JSON\n' > "$vault/appearance.json"
if python3 "$REPO_ROOT/home/scripts/iris-render.py" \
  --config-home "$config_home" \
  --profiles-dir "$profiles_dir" \
  --profile-dir "$profile_dir" \
  --obsidian-vault "$vault" >/dev/null 2>&1 <<'EOF'
{
  "fg": "#f7f2ee",
  "bg": "#14100f",
  "surface": "#261d1a",
  "dim": "#9f8d84",
  "accent": "#d8915f",
  "red": "#e17a76",
  "green": "#8ac083",
  "yellow": "#d8bd70"
}
EOF
then
  echo "FAIL: corrupt appearance.json should exit non-zero" >&2
  exit 1
fi
if ! grep -qx 'NOT JSON' "$vault/appearance.json"; then
  echo "FAIL: corrupt appearance.json was overwritten" >&2
  cat "$vault/appearance.json" >&2
  exit 1
fi

if ! command -v iris-python >/dev/null 2>&1; then
  echo "FAIL: iris-python is required for extractor checks" >&2
  exit 1
fi

export HOME="$tmpdir/iris-home"
mkdir -p "$HOME" "$tmpdir/iris-imgs"

iris-python - "$tmpdir/iris-imgs" <<'PY'
from PIL import Image
import os
import sys

base = sys.argv[1]
Image.new("RGB", (1, 1), (200, 40, 40)).save(os.path.join(base, "one.png"))
Image.new("L", (48, 48), 128).save(os.path.join(base, "grey.png"))
im = Image.new("RGBA", (32, 32), (255, 0, 0, 0))
for y in range(32):
    for x in range(16):
        im.putpixel((x, y), (0, 255, 0, 255))
im.save(os.path.join(base, "alpha.png"))
Image.new("RGB", (48, 48), (0, 220, 0)).save(os.path.join(base, "green.png"))
Image.new("RGBA", (16, 16), (0, 0, 0, 0)).save(os.path.join(base, "clear.png"))
PY
printf 'not an image' > "$tmpdir/iris-imgs/corrupt.png"

iris_out="$tmpdir/iris-out.json"
if iris-python "$REPO_ROOT/home/scripts/iris.py" \
  --wallpaper "$tmpdir/iris-imgs/corrupt.png" --dark 1 \
  >"$iris_out" 2>/dev/null; then
  echo "FAIL: corrupt wallpaper should exit non-zero" >&2
  exit 1
fi
if [ -s "$iris_out" ]; then
  echo "FAIL: corrupt wallpaper wrote a palette to stdout" >&2
  cat "$iris_out" >&2
  exit 1
fi

if iris-python "$REPO_ROOT/home/scripts/iris.py" \
  --wallpaper "$tmpdir/iris-imgs/clear.png" --dark 1 \
  >"$iris_out" 2>/dev/null; then
  echo "FAIL: fully transparent wallpaper should exit non-zero" >&2
  exit 1
fi
if [ -s "$iris_out" ]; then
  echo "FAIL: fully transparent wallpaper wrote a palette to stdout" >&2
  cat "$iris_out" >&2
  exit 1
fi

iris-python "$REPO_ROOT/home/scripts/iris.py" \
  --wallpaper "$tmpdir/iris-imgs/one.png" --dark -1 >"$iris_out"
python3 - "$iris_out" <<'PY'
import json
import sys

theme = json.load(open(sys.argv[1]))
if theme.get("bg") in ("#e8ede0", "#2d3a2e"):
    raise SystemExit(f"1x1 wallpaper used the silent fallback palette: {theme}")
for key in ("fg", "bg", "accent"):
    v = theme[key]
    if not (isinstance(v, str) and v.startswith("#") and len(v) == 7):
        raise SystemExit(f"1x1 wallpaper produced a bad {key}: {v!r}")
PY

iris-python "$REPO_ROOT/home/scripts/iris.py" \
  --wallpaper "$tmpdir/iris-imgs/grey.png" --dark -1 >"$iris_out"
python3 - "$iris_out" <<'PY'
import json
import sys

json.load(open(sys.argv[1]))
PY

iris-python "$REPO_ROOT/home/scripts/iris.py" \
  --wallpaper "$tmpdir/iris-imgs/alpha.png" --dark 0 >"$iris_out"
python3 - "$iris_out" <<'PY'
import json
import sys

theme = json.load(open(sys.argv[1]))
# Transparent red (alpha 0) must not enter the palette; opaque half is green.
h = theme["accent"].lstrip("#")
r, g, b = (int(h[i : i + 2], 16) for i in (0, 2, 4))
if r > g + 30 and r > b + 30:
    raise SystemExit(f"alpha wallpaper treated transparent RGB as color: {theme}")
PY

iris-python "$REPO_ROOT/home/scripts/iris.py" \
  --wallpaper "$tmpdir/iris-imgs/green.png" --dark 1 >"$iris_out"
python3 - "$iris_out" <<'PY'
import json
import sys


def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lum(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i : i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def contrast(a, b):
    hi, lo = max(lum(a), lum(b)), min(lum(a), lum(b))
    return (hi + 0.05) / (lo + 0.05)


theme = json.load(open(sys.argv[1]))
cr = contrast(theme["fg"], theme["bg"])
if cr < 4.5:
    raise SystemExit(
        f"forced-dark green wallpaper fg/bg contrast {cr:.2f} < 4.5 "
        f"({theme['fg']} on {theme['bg']})"
    )
PY

# Same-size in-place rewrite must not reuse a stale palette (content hash).
iris-python "$REPO_ROOT/home/scripts/iris.py" \
  --wallpaper "$tmpdir/iris-imgs/green.png" --dark 1 >"$tmpdir/first.json"
iris-python - "$tmpdir/iris-imgs/green.png" <<'PY'
from PIL import Image
import os
import sys

path = sys.argv[1]
st = os.stat(path)
Image.new("RGB", (48, 48), (40, 40, 200)).save(path)
os.utime(path, (st.st_mtime, st.st_mtime))
PY
iris-python "$REPO_ROOT/home/scripts/iris.py" \
  --wallpaper "$tmpdir/iris-imgs/green.png" --dark 1 >"$tmpdir/second.json"
if cmp -s "$tmpdir/first.json" "$tmpdir/second.json"; then
  echo "FAIL: in-place wallpaper rewrite served a stale cache" >&2
  cat "$tmpdir/first.json" >&2
  exit 1
fi

# Truncated cache must be ignored and rebuilt, not printed as stdout.
cache_dir="$HOME/.cache/wallpaper-colors"
rm -f "$cache_dir"/*.json
iris-python "$REPO_ROOT/home/scripts/iris.py" \
  --wallpaper "$tmpdir/iris-imgs/grey.png" --dark -1 >"$iris_out"
cache_file="$(find "$cache_dir" -name '*.json' -print -quit)"
[ -n "$cache_file" ] || {
  echo "FAIL: iris cache was not written" >&2
  exit 1
}
python3 - "$cache_file" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
p.write_text(p.read_text()[:40])
PY
iris-python "$REPO_ROOT/home/scripts/iris.py" \
  --wallpaper "$tmpdir/iris-imgs/grey.png" --dark -1 >"$iris_out"
python3 - "$iris_out" <<'PY'
import json
import sys

json.load(open(sys.argv[1]))
PY

echo "OK: iris-render.bash"
