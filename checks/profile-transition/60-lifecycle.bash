# shellcheck shell=bash
# Sourced by checks/profile-transition.bash; shares its globals.
# The service manager owns the long-lived bar, so the transition releases its
# lock without leaving a child process that inherited the descriptor.
printf 'noc\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
ln -sfn "$profiles/noc/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'noctalia-started\n' > "$bar_state"
printf 'noctalia\n' > "$notification_state"
: > "$log"
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  "$REPO_ROOT/home/scripts/profile-transition" switch qs
assert_log_contains 'systemctl --user start quickshell-bar.service' \
  "transition delegates Quickshell ownership to systemd"
if ! flock -n "$tmpdir/profile.lock" true; then
  printf 'FAIL: supervised bar transition retained the transition lock\n' >&2
  exit 1
fi

# Exercise two real transitions with A paused after its slow staging work. B
# must complete while the transition lock is available, and A must discard its
# stale stage when it resumes.
transition_barrier="$tmpdir/transition-stage-barrier"
mkdir -p "$transition_barrier"
printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'quickshell-started\n' > "$bar_state"
printf 'quickshell\n' > "$notification_state"
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  PROFILE_TRANSITION_TEST_SYNC_ASYNC=1 \
  PROFILE_TRANSITION_TEST_STAGE_BARRIER_DIR="$transition_barrier" \
  "$REPO_ROOT/home/scripts/profile-transition" switch new \
  >"$tmpdir/transition-a.out" 2>&1 &
transition_a=$!
for _ in $(seq 1 100); do
  [ -e "$transition_barrier/staged" ] && break
  sleep 0.02
done
[ -e "$transition_barrier/staged" ] || {
  printf 'FAIL: transition A did not reach the staging barrier\n' >&2
  kill "$transition_a" 2>/dev/null || true
  exit 1
}
if ! flock -n "$tmpdir/profile.lock" true; then
  printf 'FAIL: transition renderer retained the publication lock\n' >&2
  kill "$transition_a" 2>/dev/null || true
  exit 1
fi
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  PROFILE_TRANSITION_TEST_SYNC_ASYNC=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch qs
touch "$transition_barrier/release"
wait "$transition_a"
assert_eq qs "$(cat "$profiles/active")" \
  "late transition A cannot replace B active profile"
assert_eq dark "$(cat "$profiles/active-variant")" \
  "late transition A cannot replace B variant"
assert_eq 'gtk-old-dark' "$(cat "$home/.config/gtk-3.0/noctalia.css")" \
  "late transition A cannot replace B GTK colors"
assert_eq '{"payload":"qs-runtime-dark"}' \
  "$(cat "$profiles/runtime-quickshell-theme.json")" \
  "late transition A cannot replace B quickshell theme"
for script in "$REPO_ROOT/home/scripts/profile-transition" "$REPO_ROOT/home/scripts/toggle-bar"; do
  if rg -q 'pkill -f .*quickshell.*/shell\.qml|quickshell -p .*configs/quickshell/shell\.qml' "$script"; then
    printf 'FAIL: %s still owns the Quickshell bar process directly\n' "$script" >&2
    exit 1
  fi
done
rg -q 'systemctl --user start quickshell-bar\.service' "$REPO_ROOT/home/scripts/profile-transition" \
  || { printf 'FAIL: profile transition does not start the Quickshell service\n' >&2; exit 1; }
rg -q 'systemctl --user stop quickshell-bar\.service' "$REPO_ROOT/home/scripts/toggle-bar" \
  || { printf 'FAIL: toggle-bar does not stop the Quickshell service\n' >&2; exit 1; }

# The publisher accepts a transition's inherited lock descriptor, so synchronous
# post-commit adapters can publish without reacquiring their parent's flock.
# A boolean environment flag alone must never bypass an unrelated lock holder.
publish_profiles="$tmpdir/publish-profiles"
publish_home="$tmpdir/publish-home"
publish_lock="$tmpdir/publish.lock"
mkdir -p "$publish_profiles" "$publish_home"
exec 8>>"$publish_lock"
flock 8
inherited_generation=$(HOME="$publish_home" XDG_CONFIG_HOME="$publish_home/.config" \
  PROFILE_PUBLISH_PROFILES_DIR="$publish_profiles" PROFILE_TRANSITION_LOCK="$publish_lock" \
  PROFILE_PUBLISH_LOCK_FD=8 "$REPO_ROOT/home/scripts/profile-publish" allocate)
case "$inherited_generation" in
  '' | *[!0-9]*)
    printf 'FAIL: inherited transition lock did not allocate a generation\n' >&2
    exit 1
    ;;
esac
set +e
boolean_bypass_status=$(HOME="$publish_home" XDG_CONFIG_HOME="$publish_home/.config" \
  PROFILE_PUBLISH_PROFILES_DIR="$publish_profiles" PROFILE_TRANSITION_LOCK="$publish_lock" \
  PROFILE_PUBLISH_LOCK_HELD=1 timeout 1s "$REPO_ROOT/home/scripts/profile-publish" allocate >/dev/null 2>&1; printf '%s' "$?")
set -e
assert_eq 124 "$boolean_bypass_status" "boolean lock marker cannot bypass an active transition lock"
exec 8>&-

# A complete normal-transition stage from A must not overwrite B when A finishes
# later. Both the home and desktop-profile artifacts remain from B.
transition_stage_a="$tmpdir/transition-stage-a"
transition_stage_b="$tmpdir/transition-stage-b"
mkdir -p "$transition_stage_a/home/.config/gtk-3.0" "$transition_stage_a/profiles" \
  "$transition_stage_b/home/.config/gtk-3.0" "$transition_stage_b/profiles"
printf 'A gtk\n' > "$transition_stage_a/home/.config/gtk-3.0/noctalia.css"
printf 'A quickshell\n' > "$transition_stage_a/profiles/runtime-quickshell-theme.json"
printf 'B gtk\n' > "$transition_stage_b/home/.config/gtk-3.0/noctalia.css"
printf 'B quickshell\n' > "$transition_stage_b/profiles/runtime-quickshell-theme.json"
transition_generation_a=$(HOME="$publish_home" XDG_CONFIG_HOME="$publish_home/.config" \
  PROFILE_PUBLISH_PROFILES_DIR="$publish_profiles" PROFILE_TRANSITION_LOCK="$publish_lock" \
  "$REPO_ROOT/home/scripts/profile-publish" allocate)
HOME="$publish_home" XDG_CONFIG_HOME="$publish_home/.config" \
  PROFILE_PUBLISH_PROFILES_DIR="$publish_profiles" PROFILE_TRANSITION_LOCK="$publish_lock" \
  "$REPO_ROOT/home/scripts/profile-publish" declare "$transition_stage_a"
transition_generation_b=$(HOME="$publish_home" XDG_CONFIG_HOME="$publish_home/.config" \
  PROFILE_PUBLISH_PROFILES_DIR="$publish_profiles" PROFILE_TRANSITION_LOCK="$publish_lock" \
  "$REPO_ROOT/home/scripts/profile-publish" allocate)
HOME="$publish_home" XDG_CONFIG_HOME="$publish_home/.config" \
  PROFILE_PUBLISH_PROFILES_DIR="$publish_profiles" PROFILE_TRANSITION_LOCK="$publish_lock" \
  "$REPO_ROOT/home/scripts/profile-publish" declare "$transition_stage_b"
HOME="$publish_home" XDG_CONFIG_HOME="$publish_home/.config" \
  PROFILE_PUBLISH_PROFILES_DIR="$publish_profiles" PROFILE_TRANSITION_LOCK="$publish_lock" \
  "$REPO_ROOT/home/scripts/profile-publish" publish "$transition_generation_b" "$transition_stage_b" >/dev/null
HOME="$publish_home" XDG_CONFIG_HOME="$publish_home/.config" \
  PROFILE_PUBLISH_PROFILES_DIR="$publish_profiles" PROFILE_TRANSITION_LOCK="$publish_lock" \
  "$REPO_ROOT/home/scripts/profile-publish" publish "$transition_generation_a" "$transition_stage_a" >/dev/null
assert_eq 'B gtk' "$(cat "$publish_home/.config/gtk-3.0/noctalia.css")" \
  "late transition generation cannot replace GTK colors"
assert_eq 'B quickshell' "$(cat "$publish_profiles/runtime-quickshell-theme.json")" \
  "late transition generation cannot replace quickshell theme"

check_post_commit_adapter_isolation
check_status_accepts_runtime_niri
check_engine_variant_noops
check_startup_steady_state
check_variant_resolves_after_lock
check_lock_contention_is_nonblocking
check_public_delegation
check_legacy_runtime_regressions
