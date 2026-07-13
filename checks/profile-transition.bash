#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

home="$tmpdir/home"
profiles="$home/.config/desktop-profiles"
bin_dir="$tmpdir/bin"
log="$tmpdir/commands.log"
real_jq="$(command -v jq)"
bar_state="$tmpdir/waybar.state"

assert_eq() {
  local expected="$1" actual="$2" label="$3"

  if [ "$expected" != "$actual" ]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_log_contains() {
  local pattern="$1" label="$2"

  if ! grep -Fq -- "$pattern" "$log"; then
    printf 'FAIL: %s\nmissing log entry: %s\n' "$label" "$pattern" >&2
    exit 1
  fi
}

assert_mode() {
  local expected="$1" path="$2" label="$3"
  assert_eq "$expected" "$(stat -c '%a' "$path")" "$label"
}

check_waybar_readiness_fake() {
  printf 'stopped\n' > "$bar_state"
  : > "$log"
  if COMMAND_LOG="$log" BAR_STATE="$bar_state" XDG_CONFIG_HOME="$home/.config" PATH="$bin_dir" \
    "$bin_dir/pgrep" -f waybar; then
    printf 'FAIL: stopped Waybar reported ready\n' >&2
    exit 1
  fi
  if grep -Fq 'verify-waybar' "$log"; then
    printf 'FAIL: stopped Waybar emitted a readiness verification\n' >&2
    exit 1
  fi

  printf 'started\n' > "$bar_state"
  COMMAND_LOG="$log" BAR_STATE="$bar_state" XDG_CONFIG_HOME="$home/.config" PATH="$bin_dir" \
    "$bin_dir/pgrep" -f waybar
  assert_eq "verify-waybar active=old" "$(tail -n 1 "$log")" \
    "started Waybar emits the unique readiness verification"
}

check_public_delegation() {
  local adapter_dir="$tmpdir/public-adapters"
  local mapping public_invocation engine_invocation public_command before after diagnostics

  mkdir -p "$adapter_dir"
  cp "$REPO_ROOT/home/scripts/switch-profile" "$adapter_dir/switch-profile"
  cp "$REPO_ROOT/home/scripts/toggle-variant" "$adapter_dir/toggle-variant"
  : > "$adapter_dir/profile-common"
  cat > "$adapter_dir/profile-transition" <<'EOF'
#!/usr/bin/env bash
printf 'profile-transition %s\n' "$*" >> "$COMMAND_LOG"
EOF
  chmod +x "$adapter_dir/profile-transition"

  for mapping in "${COMPATIBILITY_MAPPINGS[@]}"; do
    IFS='|' read -r public_invocation engine_invocation <<< "$mapping"
    read -r -a public_command <<< "$public_invocation"
    : > "$log"
    diagnostics="$tmpdir/public-command.out"
    before=$(tar -C "$home" -cf - . | sha256sum)
    if ! HOME="$home" XDG_CONFIG_HOME="$home/.config" COMMAND_LOG="$log" PATH="$bin_dir" \
      "$adapter_dir/${public_command[0]}" "${public_command[@]:1}" >"$diagnostics" 2>&1; then
      printf 'FAIL: %s exited nonzero\n' "$public_invocation" >&2
      cat "$diagnostics" >&2
      exit 1
    fi
    assert_eq "$engine_invocation" "$(cat "$log")" \
      "$public_invocation delegates its mutation to the transition engine"
    after=$(tar -C "$home" -cf - . | sha256sum)
    assert_eq "$before" "$after" "$public_invocation performs no mutation outside the engine"
  done
}

mkdir -p "$profiles" "$bin_dir" "$home/.config/waybar"

for utility in awk bash basename cat chmod cp cut dirname env find flock grep head install ln mkdir \
  mktemp mv readlink rm rmdir sed seq sha256sum shuf sleep sort stat tail tar touch tr xargs; do
  utility_path=$(command -v "$utility")
  ln -s "$utility_path" "$bin_dir/$utility"
done

for profile in old new; do
  profile_dir="$profiles/$profile"
  wallpaper_dir="$profile_dir/wallpapers"
  mkdir -p "$wallpaper_dir"
  printf '{"bar":"waybar","selfThemed":false,"hasLightVariant":true,"cursor":"default","cursorSize":24}\n' \
    > "$profile_dir/meta.json"
  printf '{}\n' > "$profile_dir/runtime.json"
  printf 'old-or-new-dark\n' > "$profile_dir/kitty-colors.conf"
  printf 'old-or-new-light\n' > "$profile_dir/kitty-colors-light.conf"
  printf 'layout { gaps 8; }\n' > "$profile_dir/niri-overrides.kdl"
  printf '{"profile":"%s"}\n' "$profile" > "$profile_dir/waybar-config.jsonc"
  printf '* { color: %s-dark; }\n' "$profile" > "$profile_dir/waybar-style.css"
  printf '* { color: %s-light; }\n' "$profile" > "$profile_dir/waybar-style-light.css"
  printf '%s\n' "$wallpaper_dir" > "$profile_dir/wallpaper-dir"
  printf '%s\n' "$wallpaper_dir" > "$profile_dir/wallpaper-dir-light"
  touch "$wallpaper_dir/wallpaper.png"
done

cp -a "$profiles/old" "$profiles/qs"
printf '{"bar":"quickshell","selfThemed":false,"hasLightVariant":true,"cursor":"default","cursorSize":24}\n' \
  > "$profiles/qs/meta.json"
cp -a "$profiles/old" "$profiles/noc"
printf '{"bar":"noctalia","selfThemed":true,"hasLightVariant":false,"cursor":"default","cursorSize":24}\n' \
  > "$profiles/noc/meta.json"

cp "$profiles/old/waybar-config.jsonc" "$home/.config/waybar/config.jsonc"
cp "$profiles/old/waybar-style.css" "$home/.config/waybar/style.css"
chmod 640 "$home/.config/waybar/config.jsonc"

printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-old"
printf 'light\n' > "$profiles/variant-new"
ln -s "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"

for command in systemctl niri quickshell gsettings notify-send busctl awww mpvpaper makoctl tmux kitty magick; do
  cat > "$bin_dir/$command" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "$COMMAND_LOG"
case "$(basename "$0") $*" in
  "systemctl --user is-active"*) printf 'active\n' ;;
esac
EOF
done

cat > "$bin_dir/niri" <<'EOF'
#!/usr/bin/env bash
printf 'niri %s\n' "$*" >> "$COMMAND_LOG"
if [ -n "${NIRI_COUNT_FILE:-}" ]; then
  count=$(cat "$NIRI_COUNT_FILE" 2>/dev/null || echo 0)
  count=$((count + 1))
  printf '%s\n' "$count" > "$NIRI_COUNT_FILE"
  if [ -n "${FAIL_FIRST_NIRI:-}" ] && [ "$count" -eq 1 ]; then
    exit 17
  fi
  if [ -n "${FAIL_SECOND_NIRI:-}" ] && [ "$count" -eq 2 ]; then
    exit 1
  fi
fi
EOF

cat > "$bin_dir/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "$COMMAND_LOG"
case " $* " in
  *" stop noctalia-shell "*)
    if [ -n "${SYSTEMCTL_COUNT_FILE:-}" ]; then
      count=$(cat "$SYSTEMCTL_COUNT_FILE" 2>/dev/null || echo 0)
      count=$((count + 1))
      printf '%s\n' "$count" > "$SYSTEMCTL_COUNT_FILE"
    fi
    [ -n "${IGNORE_FIRST_NOCTALIA_STOP:-}" ] && [ "${count:-0}" -eq 1 ] \
      || printf 'stopped\n' > "$BAR_STATE"
    ;;
  *" start noctalia-shell "*) printf 'noctalia-started\n' > "$BAR_STATE" ;;
  *" is-active --quiet noctalia-shell "*)
    if [ "$(cat "$BAR_STATE")" = "noctalia-started" ]; then
      active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
      printf 'verify-noctalia active=%s\n' "$active" >> "$COMMAND_LOG"
      exit 0
    fi
    exit 3
    ;;
esac
EOF

cat > "$bin_dir/pkill" <<'EOF'
#!/usr/bin/env bash
printf 'pkill %s\n' "$*" >> "$COMMAND_LOG"
if [ -n "${PKILL_COUNT_FILE:-}" ]; then
  count=$(cat "$PKILL_COUNT_FILE" 2>/dev/null || echo 0)
  count=$((count + 1))
  printf '%s\n' "$count" > "$PKILL_COUNT_FILE"
fi
case " $* " in
  *" waybar "*)
    [ -n "${IGNORE_FIRST_BAR_STOP:-}" ] && [ "${count:-0}" -eq 1 ] || printf 'stopped\n' > "$BAR_STATE"
    ;;
  *" quickshell"*"quickshell/shell.qml"*)
    [ -n "${IGNORE_FIRST_BAR_STOP:-}" ] && [ "${count:-0}" -eq 1 ] || printf 'stopped\n' > "$BAR_STATE"
    ;;
esac
EOF

cat > "$bin_dir/waybar" <<'EOF'
#!/usr/bin/env bash
if [ -n "${START_COUNT_FILE:-}" ]; then
  count=$(cat "$START_COUNT_FILE" 2>/dev/null || echo 0)
  printf '%s\n' "$((count + 1))" > "$START_COUNT_FILE"
fi
printf 'started\n' > "$BAR_STATE"
active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
printf 'waybar start active=%s\n' "$active" >> "$COMMAND_LOG"
EOF

cat > "$bin_dir/quickshell" <<'EOF'
#!/usr/bin/env bash
printf 'quickshell-started\n' > "$BAR_STATE"
active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
printf 'quickshell start active=%s\n' "$active" >> "$COMMAND_LOG"
EOF

cat > "$bin_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
state=$(cat "$BAR_STATE")
if [ -n "${FAIL_FIRST_BAR_START:-}" ] && [ "$(cat "$START_COUNT_FILE" 2>/dev/null || echo 0)" = 1 ]; then
  printf 'pgrep %s active=%s state=%s\n' "$*" "$active" "$state" >> "$COMMAND_LOG"
  exit 1
fi
case " $* :$state" in
  *" waybar "*:started)
    printf 'verify-waybar active=%s\n' "$active" >> "$COMMAND_LOG"
    exit 0
    ;;
  *" quickshell"*"quickshell/shell.qml"*:quickshell-started)
    printf 'verify-quickshell active=%s\n' "$active" >> "$COMMAND_LOG"
    exit 0
    ;;
  *)
    printf 'pgrep %s active=%s state=%s\n' "$*" "$active" "$state" >> "$COMMAND_LOG"
    exit 1
    ;;
esac
EOF

cat > "$bin_dir/jq" <<'EOF'
#!/usr/bin/env bash
printf 'jq %s\n' "$*" >> "$COMMAND_LOG"
exec "$REAL_JQ" "$@"
EOF

find "$bin_dir" -maxdepth 1 -type f -exec chmod +x {} +
check_waybar_readiness_fake
: > "$log"

# Public mutation interfaces that later compatibility tests must enforce.
COMPATIBILITY_MAPPINGS=(
  'switch-profile new|profile-transition switch new'
  'switch-profile --reapply|profile-transition reapply'
  'switch-profile --startup|profile-transition startup'
  'toggle-variant light|profile-transition variant light'
  'toggle-variant|profile-transition variant toggle'
)
readonly -a COMPATIBILITY_MAPPINGS

HOME="$home" \
XDG_CONFIG_HOME="$home/.config" \
PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" \
COMMAND_LOG="$log" \
BAR_STATE="$bar_state" \
REAL_JQ="$real_jq" \
PATH="$bin_dir" \
  "$REPO_ROOT/home/scripts/profile-transition" switch new

assert_eq "new" "$(cat "$profiles/active")" "target profile is committed"
assert_eq "light" "$(cat "$profiles/active-variant")" "stored target variant is restored"
assert_eq "light" "$(cat "$profiles/variant-new")" "target variant preference is persisted"
assert_eq "$profiles/new/niri-overrides.kdl" \
  "$(readlink "$profiles/active-niri-overrides.kdl")" \
  "Niri override points to the target profile"
assert_log_contains "verify-waybar active=old" \
  "post-start target bar readiness is verified before active profile commit"

printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
cp "$profiles/old/waybar-config.jsonc" "$home/.config/waybar/config.jsonc"
cp "$profiles/old/waybar-style.css" "$home/.config/waybar/style.css"
chmod 640 "$home/.config/waybar/config.jsonc"
printf '0\n' > "$tmpdir/start-count"
printf '0\n' > "$tmpdir/niri-count"
: > "$log"
rollback_output="$tmpdir/rollback.out"
if HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  START_COUNT_FILE="$tmpdir/start-count" FAIL_FIRST_BAR_START=1 \
  NIRI_COUNT_FILE="$tmpdir/niri-count" FAIL_SECOND_NIRI=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch new >"$rollback_output" 2>&1; then
  printf 'FAIL: transition succeeded despite target bar readiness failure\n' >&2
  exit 1
fi
assert_eq "old" "$(cat "$profiles/active")" "rollback restores active profile"
assert_eq "dark" "$(cat "$profiles/active-variant")" "rollback restores active variant"
assert_eq "$profiles/old/niri-overrides.kdl" \
  "$(readlink "$profiles/active-niri-overrides.kdl")" \
  "rollback restores the previous Niri override"
assert_eq '{"profile":"old"}' "$(cat "$home/.config/waybar/config.jsonc")" \
  "rollback restores the previous Waybar config exactly"
assert_eq '* { color: old-dark; }' "$(cat "$home/.config/waybar/style.css")" \
  "rollback restores the previous Waybar style exactly"
assert_eq "2" "$(cat "$tmpdir/start-count")" \
  "rollback stops the target and restarts the previous bar"
assert_eq "2" "$(grep -Fc 'niri msg action load-config-file' "$log")" \
  "rollback reloads Niri after restoring the previous override"
assert_log_contains "verify-waybar active=old" "rollback verifies the previous bar"
if ! grep -Fq 'rollback: Niri reload failed' "$rollback_output"; then
  printf 'FAIL: rollback did not diagnose its injected Niri reload failure\n' >&2
  cat "$rollback_output" >&2
  exit 1
fi
assert_mode 640 "$home/.config/waybar/config.jsonc" \
  "rollback restores the previous Waybar config mode"
assert_eq "light" "$(cat "$profiles/variant-new")" \
  "rollback restores the target per-profile preference"

# Failure of the target Niri reload occurs after the link changes, so it must
# restore the link before reloading and restarting the old runtime.
printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'light\n' > "$profiles/variant-new"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
cp "$profiles/old/waybar-config.jsonc" "$home/.config/waybar/config.jsonc"
cp "$profiles/old/waybar-style.css" "$home/.config/waybar/style.css"
printf 'started\n' > "$bar_state"
printf '0\n' > "$tmpdir/niri-count"
: > "$log"
set +e
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  NIRI_COUNT_FILE="$tmpdir/niri-count" FAIL_FIRST_NIRI=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch new >/dev/null 2>&1
niri_status=$?
set -e
assert_eq 17 "$niri_status" "Niri failure preserves its original status"
assert_eq old "$(cat "$profiles/active")" "Niri rollback restores active profile"
assert_eq dark "$(cat "$profiles/active-variant")" "Niri rollback restores active variant"
assert_eq light "$(cat "$profiles/variant-new")" "Niri rollback restores target preference"
assert_eq "$profiles/old/niri-overrides.kdl" \
  "$(readlink "$profiles/active-niri-overrides.kdl")" \
  "Niri rollback restores the previous override"
assert_eq 2 "$(cat "$tmpdir/niri-count")" "Niri rollback reloads the restored override"
assert_log_contains "verify-waybar active=old" "Niri rollback recovers the previous bar"

# A staging failure must restore every snapshotted path and recover the old runtime.
printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'light\n' > "$profiles/variant-new"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf '{"profile":"old-stage"}\n' > "$home/.config/waybar/config.jsonc"
chmod 600 "$home/.config/waybar/config.jsonc"
rm -f "$home/.config/waybar/style.css"
printf 'started\n' > "$bar_state"
printf '0\n' > "$tmpdir/start-count"
: > "$log"
stage_output="$tmpdir/stage.out"
set +e
HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_RUNTIME_DIR="$tmpdir/runtime" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  PROFILE_TRANSITION_FAIL_STAGE_PATH="$home/.config/waybar/style.css" \
  "$REPO_ROOT/home/scripts/profile-transition" switch new >"$stage_output" 2>&1
stage_status=$?
set -e
if [ "$stage_status" -eq 0 ]; then
  printf 'FAIL: transition succeeded despite injected staging failure\n' >&2
  exit 1
fi
assert_eq 1 "$stage_status" "staging failure preserves original status"
assert_eq old "$(cat "$profiles/active")" "staging rollback restores active profile"
assert_eq dark "$(cat "$profiles/active-variant")" "staging rollback restores active variant"
assert_eq light "$(cat "$profiles/variant-new")" "staging rollback restores target preference"
assert_eq "$profiles/old/niri-overrides.kdl" \
  "$(readlink "$profiles/active-niri-overrides.kdl")" \
  "staging rollback restores the Niri symlink"
assert_eq '{"profile":"old-stage"}' "$(cat "$home/.config/waybar/config.jsonc")" \
  "staging rollback restores file bytes"
assert_mode 600 "$home/.config/waybar/config.jsonc" "staging rollback restores file mode"
[ ! -e "$home/.config/waybar/style.css" ] || {
  printf 'FAIL: staging rollback restores a missing path\n' >&2
  exit 1
}
assert_log_contains "verify-waybar active=old" "staging rollback recovers the previous bar"
if find "$tmpdir/runtime" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
  printf 'FAIL: staging rollback left a transaction directory behind\n' >&2
  exit 1
fi

# A restoration failure is secondary: later restores and runtime recovery continue,
# and rollback exits with the transition's original status.
printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'light\n' > "$profiles/variant-new"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf '{"profile":"old-secondary"}\n' > "$home/.config/waybar/config.jsonc"
printf '* { color: old-secondary; }\n' > "$home/.config/waybar/style.css"
printf 'started\n' > "$bar_state"
: > "$log"
secondary_output="$tmpdir/secondary.out"
set +e
HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_RUNTIME_DIR="$tmpdir/runtime" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  PROFILE_TRANSITION_FAIL_STAGE_PATH="$home/.config/waybar/style.css" \
  PROFILE_TRANSITION_FAIL_RESTORE_PATH="$home/.config/waybar/config.jsonc" \
  PROFILE_TRANSITION_FAILURE_STATUS=42 \
  "$REPO_ROOT/home/scripts/profile-transition" switch new >"$secondary_output" 2>&1
secondary_status=$?
set -e
assert_eq 42 "$secondary_status" "secondary restore failure preserves original status"
assert_eq old "$(cat "$profiles/active")" "later active restore still runs"
assert_eq dark "$(cat "$profiles/active-variant")" "later variant restore still runs"
assert_eq light "$(cat "$profiles/variant-new")" "later preference restore still runs"
assert_eq "$profiles/old/niri-overrides.kdl" \
  "$(readlink "$profiles/active-niri-overrides.kdl")" \
  "later Niri symlink restore still runs"
assert_eq '* { color: old-secondary; }' "$(cat "$home/.config/waybar/style.css")" \
  "later file restore still runs"
assert_log_contains "niri msg action load-config-file" "Niri recovery continues after restore failure"
assert_log_contains "verify-waybar active=old" "bar recovery continues after restore failure"
grep -Fq "rollback: restore $home/.config/waybar/config.jsonc failed" "$secondary_output" || {
  printf 'FAIL: secondary restoration failure was not diagnosed\n' >&2
  cat "$secondary_output" >&2
  exit 1
}

# A partially written commit is still covered until all preferences are durable.
printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-new"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
cp "$profiles/old/waybar-config.jsonc" "$home/.config/waybar/config.jsonc"
cp "$profiles/old/waybar-style.css" "$home/.config/waybar/style.css"
printf 'started\n' > "$bar_state"
: > "$log"
set +e
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  PROFILE_TRANSITION_FAIL_COMMIT_AFTER=variant \
  "$REPO_ROOT/home/scripts/profile-transition" switch new >/dev/null 2>&1
commit_status=$?
set -e
assert_eq 1 "$commit_status" "partial commit failure preserves original status"
assert_eq old "$(cat "$profiles/active")" "partial commit restores active profile"
assert_eq dark "$(cat "$profiles/active-variant")" "partial commit restores active variant"
assert_eq dark "$(cat "$profiles/variant-new")" "partial commit restores target preference"
assert_eq "$profiles/old/niri-overrides.kdl" \
  "$(readlink "$profiles/active-niri-overrides.kdl")" \
  "partial commit restores Niri override"
assert_log_contains "verify-waybar active=old" "partial commit recovers the previous bar"

printf 'new\n' > "$profiles/active"
printf 'light\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-old"
ln -sfn "$profiles/new/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
: > "$log"
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  "$REPO_ROOT/home/scripts/profile-transition" startup old
assert_eq "* { color: old-dark; }" "$(cat "$home/.config/waybar/style.css")" \
  "explicit startup target restores its saved variant"
assert_eq "new" "$(cat "$profiles/active")" "startup preserves active preference"
assert_eq "light" "$(cat "$profiles/active-variant")" "startup preserves variant preference"

printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'started\n' > "$bar_state"
printf '0\n' > "$tmpdir/pkill-count"
: > "$log"
if HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  PKILL_COUNT_FILE="$tmpdir/pkill-count" IGNORE_FIRST_BAR_STOP=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch new >/dev/null 2>&1; then
  printf 'FAIL: transition continued while Waybar remained running\n' >&2
  exit 1
fi
assert_eq "old" "$(cat "$profiles/active")" "Waybar shutdown failure aborts before commit"

printf 'qs\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-qs"
ln -sfn "$profiles/qs/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'quickshell-started\n' > "$bar_state"
printf '0\n' > "$tmpdir/pkill-count"
: > "$log"
if HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  PKILL_COUNT_FILE="$tmpdir/pkill-count" IGNORE_FIRST_BAR_STOP=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch old >/dev/null 2>&1; then
  printf 'FAIL: transition continued while Quickshell remained running\n' >&2
  exit 1
fi
assert_eq "qs" "$(cat "$profiles/active")" "Quickshell shutdown failure aborts before commit"
assert_log_contains "verify-quickshell active=qs" "rollback verifies restarted Quickshell"

printf 'noc\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-noc"
ln -sfn "$profiles/noc/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'noctalia-started\n' > "$bar_state"
printf '0\n' > "$tmpdir/systemctl-count"
: > "$log"
if HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  SYSTEMCTL_COUNT_FILE="$tmpdir/systemctl-count" IGNORE_FIRST_NOCTALIA_STOP=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch old >/dev/null 2>&1; then
  printf 'FAIL: transition continued while Noctalia remained running\n' >&2
  exit 1
fi
assert_eq "noc" "$(cat "$profiles/active")" "Noctalia shutdown failure aborts before commit"
assert_log_contains "verify-noctalia active=noc" "rollback verifies restarted Noctalia"

if [ "${PROFILE_TRANSITION_TEST_SCOPE:-full}" != "core" ]; then
  check_public_delegation
fi
