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

# Empty file: creates the section.
empty_ini="$tmpdir/empty.ini"
: > "$empty_ini"
python3 "$REPO_ROOT/home/scripts/merge-ini-section" "$empty_ini" "tinted" "$body"
if ! grep -Fqx '[tinted]' "$empty_ini"; then
  echo "FAIL: empty file did not gain a [tinted] section" >&2
  cat "$empty_ini" >&2
  exit 1
fi

# CRLF input is accepted; the matching section is replaced once.
printf '[Comfy]\r\ntext = FF\r\n\r\n[tinted]\r\ntext = OLD\r\n' > "$tmpdir/crlf.ini"
python3 "$REPO_ROOT/home/scripts/merge-ini-section" "$tmpdir/crlf.ini" "tinted" "$body"
tinted_count=$(grep -c '^\[tinted\]$' "$tmpdir/crlf.ini" || true)
if [ "$tinted_count" != 1 ]; then
  printf 'FAIL: CRLF file expected one [tinted] section, got %s\n' "$tinted_count" >&2
  cat "$tmpdir/crlf.ini" >&2
  exit 1
fi
if ! grep -Fqx '[Comfy]' "$tmpdir/crlf.ini"; then
  echo "FAIL: CRLF merge dropped [Comfy]" >&2
  cat "$tmpdir/crlf.ini" >&2
  exit 1
fi

# Duplicate sections are collapsed to one replacement.
cat > "$tmpdir/dup.ini" <<'EOF'
[Comfy]
text = FF

[tinted]
text = A

[Nord]
text = BB

[tinted]
text = C
EOF
python3 "$REPO_ROOT/home/scripts/merge-ini-section" "$tmpdir/dup.ini" "tinted" "$body"
tinted_count=$(grep -c '^\[tinted\]$' "$tmpdir/dup.ini" || true)
if [ "$tinted_count" != 1 ]; then
  printf 'FAIL: duplicate [tinted] expected collapse to one, got %s\n' "$tinted_count" >&2
  cat "$tmpdir/dup.ini" >&2
  exit 1
fi
if ! grep -Fqx '[Nord]' "$tmpdir/dup.ini"; then
  echo "FAIL: duplicate-section merge dropped [Nord]" >&2
  cat "$tmpdir/dup.ini" >&2
  exit 1
fi

# Indented headers still count as the same section.
cat > "$tmpdir/ws.ini" <<'EOF'
[Comfy]
text = FF

 [tinted]
text = OLD
EOF
python3 "$REPO_ROOT/home/scripts/merge-ini-section" "$tmpdir/ws.ini" "tinted" "$body"
tinted_count=$(grep -c '^\[tinted\]$' "$tmpdir/ws.ini" || true)
if [ "$tinted_count" != 1 ]; then
  printf 'FAIL: whitespace header expected one [tinted] section, got %s\n' "$tinted_count" >&2
  cat "$tmpdir/ws.ini" >&2
  exit 1
fi
if grep -q 'OLD' "$tmpdir/ws.ini"; then
  echo "FAIL: whitespace-header merge left the old body" >&2
  cat "$tmpdir/ws.ini" >&2
  exit 1
fi

echo "OK: merge-ini-section.bash"
