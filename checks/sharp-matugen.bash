#!/usr/bin/env bash
# on_primary / on_*_container at matugenContrast 0.5 are ink (#000000/#ffffff), not accent.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$REPO_ROOT/home/configs/matugen/templates-sharp"

if ! command -v matugen >/dev/null 2>&1; then
  echo "FAIL: matugen is required for checks/sharp-matugen.bash" >&2
  exit 1
fi

for f in kitty-colors.conf fish-theme.fish; do
  if grep -E -q '\{\{colors\.on_primary|\{\{colors\.on_(secondary|tertiary|error)_container' \
    "$TEMPLATES/$f"; then
    printf 'FAIL: %s uses an on_* container/primary token (goes black/white at high contrast)\n' \
      "$f" >&2
    exit 1
  fi
done

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cfg="$tmpdir/config.toml"
cat >"$cfg" <<EOF
[config]

[templates.kitty]
input_path = "$TEMPLATES/kitty-colors.conf"
output_path = "$tmpdir/kitty.conf"

[templates.fish]
input_path = "$TEMPLATES/fish-theme.fish"
output_path = "$tmpdir/fish.fish"
EOF

# Vivid seed + sharp's contrast reproduces the live #000000 failure mode.
seed="#fe9004"
contrast="0.5"

for mode in dark light; do
  if ! matugen color hex "$seed" --mode "$mode" --type scheme-tonal-spot \
    --contrast "$contrast" -c "$cfg" --quiet; then
    printf 'FAIL: matugen %s render failed\n' "$mode" >&2
    exit 1
  fi
  python3 - "$tmpdir/kitty.conf" "$tmpdir/fish.fish" "$mode" <<'PY'
import re
import sys

kitty_path, fish_path, mode = sys.argv[1:4]


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


kitty = {}
for line in open(kitty_path):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    k, _, v = line.partition(" ")
    kitty[k] = v.strip()

bg = kitty["background"]
# color0 is ANSI black (a fill), not a text slot. cursor_text sits on the cursor.
text_keys = ["foreground", "cursor"] + [f"color{i}" for i in range(1, 16)]
# 2.0 catches ink-on-same-surface (#000000 on near-black / #ffffff on white)
# without failing sharp's vivid source_color on a light background (~2.28).
floor = 2.0
bad = []
for key in text_keys:
    c = kitty[key]
    cr = contrast(c, bg)
    if cr < floor:
        bad.append(f"kitty {key} {c} on {bg} contrast {cr:.2f}")

sel_fg, sel_bg = kitty["selection_foreground"], kitty["selection_background"]
cr = contrast(sel_fg, sel_bg)
if cr < floor:
    bad.append(f"kitty selection {sel_fg} on {sel_bg} contrast {cr:.2f}")

cur, cur_text = kitty["cursor"], kitty["cursor_text_color"]
cr = contrast(cur, cur_text)
if cr < floor:
    bad.append(f"kitty cursor_text {cur_text} on cursor {cur} contrast {cr:.2f}")

for line in open(fish_path):
    if line.lstrip().startswith("#") or "--background=" in line:
        continue
    for c in re.findall(r"#[0-9A-Fa-f]{6}", line):
        cr = contrast(c, bg)
        if cr < floor:
            bad.append(f"fish {c} on kitty bg {bg} contrast {cr:.2f} ({line.strip()})")

if bad:
    print(f"FAIL: sharp {mode} kitty/fish text is unreadable:", file=sys.stderr)
    print("\n".join(bad), file=sys.stderr)
    sys.exit(1)
PY
done

echo "OK: sharp-matugen.bash"
