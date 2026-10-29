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
export PROFILES_DIR="$tmpdir/profiles"
runtime_file="$PROFILES_DIR/tinted/manifest.json"
log_file="$tmpdir/commands.log"
mkdir -p "$bin_dir" "$(dirname "$runtime_file")"

cat > "$runtime_file" <<'EOF'
{
  "schemaVersion": 1,
  "name": "tinted",
  "variants": { "dark": { "adapters": { "spicetify": {
    "theme": "Comfy", "scheme": "tinted", "js": 0
  } } } }
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

state="$tmpdir/activation"
mkdir -p "$state/app/Apps"
touch "$state/app/Apps/xpui.spa"
cat > "$bin_dir/spicetify" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$COMMAND_LOG"
exit "${APPLY_STATUS:-0}"
EOF

: > "$log_file"
if COMMAND_LOG="$log_file" APPLY_STATUS=1 bash "$REPO_ROOT/home/scripts/spicetify-apply" "$state" sig-a fresh "$bin_dir/spicetify"; then
  printf 'FAIL: failed apply returned success\n' >&2
  exit 1
fi
[ ! -e "$state/.apply-stamp" ]
COMMAND_LOG="$log_file" bash "$REPO_ROOT/home/scripts/spicetify-apply" "$state" sig-a '' "$bin_dir/spicetify"
assert_eq sig-a "$(cat "$state/.apply-stamp")" 'retry stamps a successful apply'
COMMAND_LOG="$log_file" bash "$REPO_ROOT/home/scripts/spicetify-apply" "$state" sig-a '' "$bin_dir/spicetify"
assert_eq 2 "$(wc -l < "$log_file" | tr -d ' ')" 'unchanged successful activation skips apply'

if COMMAND_LOG="$log_file" APPLY_STATUS=1 bash "$REPO_ROOT/home/scripts/spicetify-apply" "$state" sig-a fresh "$bin_dir/spicetify"; then
  exit 1
fi
[ ! -e "$state/.apply-stamp" ]
COMMAND_LOG="$log_file" bash "$REPO_ROOT/home/scripts/spicetify-apply" "$state" sig-a '' "$bin_dir/spicetify"
assert_eq sig-a "$(cat "$state/.apply-stamp")" 'fresh-copy failure removes an older matching stamp'
COMMAND_LOG="$log_file" DRY_RUN_CMD=echo bash "$REPO_ROOT/home/scripts/spicetify-apply" "$state" sig-b fresh "$bin_dir/spicetify"
assert_eq sig-a "$(cat "$state/.apply-stamp")" 'dry activation preserves the stamp'

# Reseed recovery: consumed xpui.spa plus a stale recorded backup fails bare
# apply forever; a store copy reseeds the .spa and one backup retry heals it.
rstate="$tmpdir/reseed-state"
mkdir -p "$rstate/app/Apps"
rstore="$tmpdir/store/spotify"
mkdir -p "$rstore/Apps"
touch "$rstore/Apps/xpui.spa" "$rstore/Apps/login.spa"
cat > "$bin_dir/spicetify" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$COMMAND_LOG"
case " $* " in
  *" backup "*) exit 0 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$bin_dir/spicetify"
: > "$log_file"
COMMAND_LOG="$log_file" PATH="$bin_dir:$PATH" bash "$REPO_ROOT/home/scripts/spicetify-apply" \
  "$rstate" sig-r '' "$bin_dir/spicetify" "$rstore"
assert_eq sig-r "$(cat "$rstate/.apply-stamp")" 'reseed retry stamps a successful apply'
[ -f "$rstate/app/Apps/xpui.spa" ]
[ "$(wc -l < "$log_file" | tr -d ' ')" = 2 ]
