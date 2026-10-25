# shellcheck shell=bash
# Sourced by checks/profile-transition.bash; shares its globals.
check_quickshell_readiness_fake
printf 'stopped\n' > "$bar_state"
printf 'none\n' > "$notification_state"
: > "$log"

check_snapshot_failure payload 23
check_snapshot_failure manifest 24
check_snapshot_signal_cleanup
check_unusual_snapshot_paths

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
assert_log_contains "verify-quickshell active=old" \
  "post-start target bar readiness is verified before active profile commit"
assert_eq 'gtk-new-light' "$(cat "$home/.config/gtk-3.0/noctalia.css")" \
  "old-to-new switch installs the target variant GTK colors"
if ! rg -Fq 'profile-publish' "$REPO_ROOT/home/scripts/profile-transition"; then
  printf 'FAIL: profile transitions do not publish their staged theme through profile-publish\n' >&2
  exit 1
fi
if ! rg -Fq 'PROFILE_PUBLISH_LOCK_FD=9' "$REPO_ROOT/home/scripts/profile-transition"; then
  printf 'FAIL: profile transition does not retain publication ownership while publishing\n' >&2
  exit 1
fi
assert_eq $'$font = Fixture UI\n$mono_font = Fixture Mono' \
  "$(cat "$home/.config/hypr/profile-font.conf")" \
  "switch installs hyprlock profile fonts"

printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
cp "$profiles/old/gtk-3.0.css" "$home/.config/gtk-3.0/noctalia.css"
chmod 640 "$home/.config/gtk-3.0/noctalia.css"
printf 'stopped\n' > "$bar_state"
printf 'none\n' > "$notification_state"
printf '0\n' > "$tmpdir/start-count"
printf '0\n' > "$tmpdir/niri-count"
: > "$log"
rollback_output="$tmpdir/rollback.out"
if HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  PROFILE_TRANSITION_VERIFY_ATTEMPTS=5 \
  START_COUNT_FILE="$tmpdir/start-count" FAIL_FIRST_BAR_START=1 \
  NIRI_COUNT_FILE="$tmpdir/niri-count" FAIL_FIRST_NIRI=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch new >"$rollback_output" 2>&1; then
  printf 'FAIL: transition succeeded despite target bar readiness failure\n' >&2
  exit 1
fi
assert_eq "old" "$(cat "$profiles/active")" "rollback restores active profile"
assert_eq "dark" "$(cat "$profiles/active-variant")" "rollback restores active variant"
assert_eq "$profiles/old/niri-overrides.kdl" \
  "$(readlink "$profiles/active-niri-overrides.kdl")" \
  "rollback restores the previous Niri override"
assert_eq 'gtk-old-dark' "$(cat "$home/.config/gtk-3.0/noctalia.css")" \
  "rollback restores the previous GTK colors exactly"
assert_eq "2" "$(cat "$tmpdir/start-count")" \
  "rollback stops the target and restarts the previous bar"
assert_eq "1" "$(grep -Fc 'niri msg action load-config-file' "$log")" \
  "rollback reloads Niri after restoring the previous override"
assert_log_contains "verify-quickshell active=old" "rollback verifies the previous bar"
if ! grep -Fq 'rollback: Niri reload failed' "$rollback_output"; then
  printf 'FAIL: rollback did not diagnose its injected Niri reload failure\n' >&2
  cat "$rollback_output" >&2
  exit 1
fi
assert_mode 640 "$home/.config/gtk-3.0/noctalia.css" \
  "rollback restores the previous GTK color file mode"
assert_eq "light" "$(cat "$profiles/variant-new")" \
  "rollback restores the target per-profile preference"

# Failure of the target Niri reload occurs after the link changes, so it must
# restore the link before reloading and restarting the old runtime.
printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'light\n' > "$profiles/variant-new"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
cp "$profiles/old/gtk-3.0.css" "$home/.config/gtk-3.0/noctalia.css"
cp "$profiles/old/gtk-4.0.css" "$home/.config/gtk-4.0/noctalia.css"
printf 'quickshell-started\n' > "$bar_state"
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
assert_log_contains "verify-quickshell active=old" "Niri rollback recovers the previous bar"

# A staging failure must restore every snapshotted path and recover the old runtime.
printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'light\n' > "$profiles/variant-new"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'gtk-old-stage\n' > "$home/.config/gtk-3.0/noctalia.css"
chmod 600 "$home/.config/gtk-3.0/noctalia.css"
rm -f "$home/.config/kitty/colors.conf"
printf 'quickshell-started\n' > "$bar_state"
printf '0\n' > "$tmpdir/start-count"
: > "$log"
stage_output="$tmpdir/stage.out"
set +e
HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_RUNTIME_DIR="$tmpdir/runtime" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  PROFILE_TRANSITION_FAIL_STAGE_PATH="$home/.config/kitty/colors.conf" \
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
assert_eq 'gtk-old-stage' "$(cat "$home/.config/gtk-3.0/noctalia.css")" \
  "staging rollback restores file bytes"
assert_mode 600 "$home/.config/gtk-3.0/noctalia.css" "staging rollback restores file mode"
[ ! -e "$home/.config/kitty/colors.conf" ] || {
  printf 'FAIL: staging rollback restores a missing path\n' >&2
  exit 1
}
assert_log_not_contains "systemctl --user stop quickshell-bar.service" "staging failure occurs before old bar shutdown"
assert_log_not_contains "verify-quickshell active=old" "staging failure needs no bar recovery"
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
printf 'gtk-old-secondary\n' > "$home/.config/gtk-3.0/noctalia.css"
printf 'gtk4-old-secondary\n' > "$home/.config/gtk-4.0/noctalia.css"
printf 'quickshell-started\n' > "$bar_state"
: > "$log"
secondary_output="$tmpdir/secondary.out"
set +e
HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_RUNTIME_DIR="$tmpdir/runtime" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  PROFILE_TRANSITION_FAIL_INSTALL_PATH="$home/.config/gtk-4.0/noctalia.css" \
  PROFILE_TRANSITION_FAIL_RESTORE_PATH="$home/.config/gtk-3.0/noctalia.css" \
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
assert_eq 'gtk4-old-secondary' "$(cat "$home/.config/gtk-4.0/noctalia.css")" \
  "later file restore still runs"
assert_log_contains "niri msg action load-config-file" "Niri recovery continues after restore failure"
assert_log_contains "verify-quickshell active=old" "bar recovery continues after restore failure"
grep -Fq "rollback: restore $home/.config/gtk-3.0/noctalia.css failed" "$secondary_output" || {
  printf 'FAIL: secondary restoration failure was not diagnosed\n' >&2
  cat "$secondary_output" >&2
  exit 1
}

# A partially written commit is still covered until all preferences are durable.
printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-new"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
cp "$profiles/old/gtk-3.0.css" "$home/.config/gtk-3.0/noctalia.css"
cp "$profiles/old/gtk-4.0.css" "$home/.config/gtk-4.0/noctalia.css"
printf 'quickshell-started\n' > "$bar_state"
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
assert_log_contains "verify-quickshell active=old" "partial commit recovers the previous bar"
assert_pending_cleared "partial commit rollback"

# Once all preferences are durable, a signal may clean transaction storage but
# must not roll the committed state or runtime back.
printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'light\n' > "$profiles/variant-new"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
cp "$profiles/old/gtk-3.0.css" "$home/.config/gtk-3.0/noctalia.css"
cp "$profiles/old/gtk-4.0.css" "$home/.config/gtk-4.0/noctalia.css"
printf 'stopped\n' > "$bar_state"
printf 'none\n' > "$notification_state"
printf '0\n' > "$tmpdir/start-count"
: > "$log"
set +e
HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_RUNTIME_DIR="$tmpdir/runtime-commit" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  START_COUNT_FILE="$tmpdir/start-count" PROFILE_TRANSITION_SIGNAL_AFTER_COMMIT=TERM \
  "$REPO_ROOT/home/scripts/profile-transition" switch new >/dev/null 2>&1
committed_signal_status=$?
set -e
assert_eq 143 "$committed_signal_status" "committed cleanup signal preserves status"
assert_eq new "$(cat "$profiles/active")" "committed cleanup signal preserves active profile"
assert_eq light "$(cat "$profiles/active-variant")" "committed cleanup signal preserves variant"
assert_eq light "$(cat "$profiles/variant-new")" "committed cleanup signal preserves preference"
assert_eq "$profiles/new/niri-overrides.kdl" \
  "$(readlink "$profiles/active-niri-overrides.kdl")" \
  "committed cleanup signal preserves Niri override"
assert_eq 1 "$(cat "$tmpdir/start-count")" \
  "committed cleanup signal does not restart the old runtime"
if find "$tmpdir/runtime-commit" -mindepth 1 -print -quit | grep -q .; then
  printf 'FAIL: committed cleanup signal left a transaction directory behind\n' >&2
  exit 1
fi

printf 'new\n' > "$profiles/active"
printf 'light\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-old"
ln -sfn "$profiles/new/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
: > "$log"
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  "$REPO_ROOT/home/scripts/profile-transition" startup old
assert_eq 'gtk-old-dark' "$(cat "$home/.config/gtk-3.0/noctalia.css")" \
  "explicit startup target restores its saved variant"
assert_eq "new" "$(cat "$profiles/active")" "startup preserves active preference"
assert_eq "light" "$(cat "$profiles/active-variant")" "startup preserves variant preference"

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
  "$REPO_ROOT/home/scripts/profile-transition" switch noc >/dev/null 2>&1; then
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
