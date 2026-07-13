#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

color_ini="$tmpdir/color.ini"
body="$tmpdir/body.ini"
cat > "$color_ini" <<'EOF'
[Comfy]
text = FFFFFF
main = 23283D

[tinted]
text = F7F2EE
main = 14100F
EOF

cat > "$body" <<'EOF'
text               = F2F2F2
subtext            = 8A8A8A
main               = 141414
main-elevated      = 1C1C1C
button             = D8915F
play-button        = D8915F
progress-fg        = D8915F
EOF

python3 "$REPO_ROOT/home/scripts/merge-ini-section" "$color_ini" "sharp" "$body"

assert_contains() {
  local needle="$1" label="$2"
  if ! grep -Fqx "$needle" "$color_ini"; then
    printf 'FAIL: %s\nmissing: %s\nfile:\n' "$label" "$needle" >&2
    cat "$color_ini" >&2
    exit 1
  fi
}

assert_contains "[Comfy]" "existing Comfy scheme is preserved"
assert_contains "[tinted]" "existing tinted scheme is preserved"
assert_contains "[sharp]" "sharp scheme is generated"
assert_contains "main               = 141414" "sharp main uses staged surface"
assert_contains "button             = D8915F" "sharp button uses staged accent"

# Re-merge updates sharp without duplicating the section.
cat > "$body" <<'EOF'
text               = F2F2F2
main               = 0A0A0A
button             = AABBCC
EOF
python3 "$REPO_ROOT/home/scripts/merge-ini-section" "$color_ini" "sharp" "$body"

sharp_count=$(grep -c '^\[sharp\]$' "$color_ini" || true)
if [ "$sharp_count" != 1 ]; then
  printf 'FAIL: expected one [sharp] section, got %s\n' "$sharp_count" >&2
  cat "$color_ini" >&2
  exit 1
fi
assert_contains "main               = 0A0A0A" "re-merge replaces sharp body"
assert_contains "button             = AABBCC" "re-merge updates accent"
assert_contains "[tinted]" "re-merge still preserves tinted"
