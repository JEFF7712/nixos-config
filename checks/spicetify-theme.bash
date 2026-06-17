#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$REPO_ROOT/home/scripts/profile-common"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

assert_eq() {
  local expected="$1" actual="$2" label="$3"

  if [ "$expected" != "$actual" ]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

bin_dir="$tmpdir/bin"
runtime_file="$tmpdir/runtime.json"
log_file="$tmpdir/commands.log"
mkdir -p "$bin_dir"

cat > "$runtime_file" <<'EOF'
{
  "spicetify": {
    "dark": {
      "theme": "Comfy",
      "scheme": "tinted",
      "js": 0
    }
  }
}
EOF

cat > "$bin_dir/spicetify" <<'EOF'
#!/usr/bin/env bash
printf 'spicetify %s\n' "$*" >> "$COMMAND_LOG"
EOF
cat > "$bin_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
printf 'pgrep %s\n' "$*" >> "$COMMAND_LOG"
exit 0
EOF
cat > "$bin_dir/niri" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "msg -j focused-window")
    printf '{"id":608,"app_id":"kitty"}\n'
    ;;
  *)
    printf 'niri %s\n' "$*" >> "$COMMAND_LOG"
    ;;
esac
EOF
chmod +x "$bin_dir/spicetify" "$bin_dir/pgrep" "$bin_dir/niri"

COMMAND_LOG="$log_file" PATH="$bin_dir:$PATH" apply_spicetify_theme "$runtime_file" dark

assert_eq $'spicetify config current_theme Comfy color_scheme tinted inject_theme_js 0\npgrep -f spotify-spiced\nspicetify refresh\nniri msg action focus-window --id 608' \
  "$(cat "$log_file")" \
  "running Spotify refreshes live and restores prior focus"

cat > "$bin_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
printf 'pgrep %s\n' "$*" >> "$COMMAND_LOG"
exit 1
EOF
chmod +x "$bin_dir/pgrep"

: > "$log_file"
COMMAND_LOG="$log_file" PATH="$bin_dir:$PATH" apply_spicetify_theme "$runtime_file" dark

assert_eq $'spicetify config current_theme Comfy color_scheme tinted inject_theme_js 0\npgrep -f spotify-spiced\nspicetify -n apply' \
  "$(cat "$log_file")" \
  "closed Spotify is patched without launching"
