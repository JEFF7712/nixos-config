#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"

home="$tmpdir/home"
profiles="$home/.config/desktop-profiles"
bin_dir="$tmpdir/bin"
log="$tmpdir/commands.log"
real_jq="$(command -v jq)"
bar_state="$tmpdir/waybar.state"
notification_state="$tmpdir/notification.state"
persistent_pid_dir="$tmpdir/persistent-pids"
export PROFILE_THEME_SELECTOR="$REPO_ROOT/home/scripts/select-quickshell-theme"
export NOTIFICATION_STATE="$notification_state"
export PERSISTENT_PID_DIR="$persistent_pid_dir"

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

assert_log_not_contains() {
  local pattern="$1" label="$2"

  if grep -Fq -- "$pattern" "$log"; then
    printf 'FAIL: %s\nunexpected log entry: %s\n' "$label" "$pattern" >&2
    exit 1
  fi
}

assert_log_contains_eventually() {
  local pattern="$1" label="$2"
  for _ in $(seq 1 20); do
    grep -Fq -- "$pattern" "$log" && return 0
    sleep 0.05
  done
  printf 'FAIL: %s\nmissing log entry: %s\n' "$label" "$pattern" >&2
  exit 1
}

assert_mode() {
  local expected="$1" path="$2" label="$3"
  assert_eq "$expected" "$(stat -c '%a' "$path")" "$label"
}

stop_persistent_children() {
  local pid_file pid alive
  local -a pids=()
  for pid_file in "$persistent_pid_dir"/*; do
    [ -f "$pid_file" ] || continue
    pid=$(cat "$pid_file")
    pids+=("$pid")
    kill "$pid" 2>/dev/null || true
  done
  for _ in $(seq 1 20); do
    alive=0
    for pid in "${pids[@]}"; do
      kill -0 "$pid" 2>/dev/null && alive=1
    done
    [ "$alive" -eq 1 ] || break
    sleep 0.05
  done
  for pid in "${pids[@]}"; do
    kill -KILL "$pid" 2>/dev/null || true
  done
  rm -rf "$persistent_pid_dir"
}

stop_fixture_jobs() {
  local pid
  while IFS= read -r pid; do
    kill "$pid" 2>/dev/null || true
  done < <(jobs -pr)
  wait 2>/dev/null || true
}

trap 'stop_fixture_jobs; stop_persistent_children; rm -rf "$tmpdir"' EXIT

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
  local engine_log="$tmpdir/public-engine.log"
  local mapping public_invocation engine_invocation public_command before after diagnostics invocation expected_variant
  local -a variant_args=()

  mkdir -p "$adapter_dir"
  cp "$REPO_ROOT/home/scripts/switch-profile" "$adapter_dir/switch-profile"
  cp "$REPO_ROOT/home/scripts/toggle-variant" "$adapter_dir/toggle-variant"
  cp "$REPO_ROOT/home/scripts/profile-common" "$adapter_dir/profile-common"
  cp "$REPO_ROOT/home/scripts/profile-manifest" "$adapter_dir/profile-manifest"
  cat > "$adapter_dir/profile-transition" <<'EOF'
#!/usr/bin/env bash
printf 'profile-transition %s\n' "$*" >> "$ENGINE_LOG"
EOF
  chmod +x "$adapter_dir/profile-transition"

  printf 'old\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  for mapping in "${COMPATIBILITY_MAPPINGS[@]}"; do
    IFS='|' read -r public_invocation engine_invocation <<< "$mapping"
    read -r -a public_command <<< "$public_invocation"
    : > "$log"
    : > "$engine_log"
    diagnostics="$tmpdir/public-command.out"
    before=$(tar -C "$home" -cf - . | sha256sum)
    if ! HOME="$home" XDG_CONFIG_HOME="$home/.config" COMMAND_LOG="$log" \
      ENGINE_LOG="$engine_log" REAL_JQ="$real_jq" PATH="$bin_dir" \
      "$adapter_dir/${public_command[0]}" "${public_command[@]:1}" >"$diagnostics" 2>&1; then
      printf 'FAIL: %s exited nonzero\n' "$public_invocation" >&2
      cat "$diagnostics" >&2
      exit 1
    fi
    assert_eq "$engine_invocation" "$(cat "$engine_log")" \
      "$public_invocation delegates its mutation to the transition engine"
    after=$(tar -C "$home" -cf - . | sha256sum)
    assert_eq "$before" "$after" "$public_invocation performs no mutation outside the engine"
  done

  printf 'noc\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  for invocation in '' light; do
    : > "$log"
    : > "$engine_log"
    variant_args=()
    [ -z "$invocation" ] || variant_args+=("$invocation")
    before=$(tar -C "$home" -cf - . | sha256sum)
    HOME="$home" XDG_CONFIG_HOME="$home/.config" COMMAND_LOG="$log" \
      ENGINE_LOG="$engine_log" REAL_JQ="$real_jq" PATH="$bin_dir" \
      "$adapter_dir/toggle-variant" "${variant_args[@]}" >"$diagnostics" 2>&1
    expected_variant="${invocation:-toggle}"
    assert_eq "profile-transition variant $expected_variant" "$(cat "$engine_log")" \
      "no-light profile variant invocation delegates its decision"
    after=$(tar -C "$home" -cf - . | sha256sum)
    assert_eq "$before" "$after" \
      "no-light profile variant invocation leaves state untouched"
  done

  printf 'old\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  : > "$log"
  : > "$engine_log"
  before=$(tar -C "$home" -cf - . | sha256sum)
  HOME="$home" XDG_CONFIG_HOME="$home/.config" COMMAND_LOG="$log" \
    ENGINE_LOG="$engine_log" REAL_JQ="$real_jq" PATH="$bin_dir" \
    "$adapter_dir/toggle-variant" dark >"$diagnostics" 2>&1
  assert_eq "profile-transition variant dark" "$(cat "$engine_log")" \
    "explicit current variant delegates its decision"
  after=$(tar -C "$home" -cf - . | sha256sum)
  assert_eq "$before" "$after" "explicit current variant leaves state untouched"
}

run_fixture_transition() {
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
    BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
    "$REPO_ROOT/home/scripts/profile-transition" "$@"
}

check_engine_variant_noops() {
  local before after invocation output="$tmpdir/variant-noop.out"

  printf 'noc\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'dark\n' > "$profiles/variant-noc"
  ln -sfn "$profiles/noc/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  for invocation in toggle light; do
    : > "$log"
    before=$(tar -C "$home" -cf - . | sha256sum)
    if ! run_fixture_transition variant "$invocation" >"$output" 2>&1; then
      printf 'FAIL: no-light %s request exited nonzero\n' "$invocation" >&2
      cat "$output" >&2
      exit 1
    fi
    after=$(tar -C "$home" -cf - . | sha256sum)
    assert_eq "$before" "$after" \
      "no-light $invocation request is an engine no-op"
    assert_log_not_contains 'niri msg action load-config-file' \
      "no-light $invocation request stops before core mutation"
  done

  printf 'old\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'dark\n' > "$profiles/variant-old"
  ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  : > "$log"
  before=$(tar -C "$home" -cf - . | sha256sum)
  if ! run_fixture_transition variant dark >"$output" 2>&1; then
    printf 'FAIL: explicit current variant exited nonzero\n' >&2
    cat "$output" >&2
    exit 1
  fi
  after=$(tar -C "$home" -cf - . | sha256sum)
  assert_eq "$before" "$after" "explicit current variant is an engine no-op"
  assert_log_not_contains 'niri msg action load-config-file' \
    "explicit current variant stops before core mutation"
}

check_variant_resolves_after_lock() {
  local pid output="$tmpdir/variant-after-lock.out" hook="$tmpdir/variant-after-lock-hook"

  printf 'old\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'dark\n' > "$profiles/variant-old"
  ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  printf 'started\n' > "$bar_state"
  printf 'mako\n' > "$notification_state"
  : > "$log"

  mkdir -p "$hook"
  PROFILE_TRANSITION_TEST_AFTER_LOCK_DIR="$hook" \
    run_fixture_transition variant toggle >"$output" 2>&1 &
  pid=$!
  for _ in $(seq 1 50); do
    [ -e "$hook/acquired" ] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.02
  done
  if [ ! -e "$hook/acquired" ]; then
    wait "$pid" || true
    printf 'FAIL: variant request did not expose the post-lock test hook\n' >&2
    cat "$output" >&2
    exit 1
  fi

  printf 'new\n' > "$profiles/active"
  printf 'light\n' > "$profiles/active-variant"
  printf 'light\n' > "$profiles/variant-new"
  ln -sfn "$profiles/new/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  touch "$hook/release"
  wait "$pid"

  assert_eq new "$(cat "$profiles/active")" \
    "queued toggle resolves the active profile after locking"
  assert_eq dark "$(cat "$profiles/active-variant")" \
    "queued toggle resolves the current variant after locking"
  assert_eq dark "$(cat "$profiles/variant-new")" \
    "queued toggle persists the post-lock target preference"
  assert_eq "$profiles/new/niri-overrides.kdl" \
    "$(readlink "$profiles/active-niri-overrides.kdl")" \
    "queued toggle applies the post-lock profile override"
}

check_lock_contention_is_nonblocking() {
  local first_pid contender_status
  local hook="$tmpdir/contention-hook" contender_output="$tmpdir/contention.out"

  printf 'old\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'dark\n' > "$profiles/variant-old"
  ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  printf 'started\n' > "$bar_state"
  printf 'mako\n' > "$notification_state"

  mkdir -p "$hook"
  PROFILE_TRANSITION_TEST_AFTER_LOCK_DIR="$hook" \
    run_fixture_transition variant toggle >"$tmpdir/contention-owner.out" 2>&1 &
  first_pid=$!
  for _ in $(seq 1 50); do
    [ -e "$hook/acquired" ] && break
    kill -0 "$first_pid" 2>/dev/null || break
    sleep 0.02
  done
  [ -e "$hook/acquired" ] || {
    wait "$first_pid" || true
    printf 'FAIL: contention owner did not acquire the lock\n' >&2
    exit 1
  }

  set +e
  run_fixture_transition variant toggle >"$contender_output" 2>&1
  contender_status=$?
  set -e
  assert_eq 75 "$contender_status" "lock contender fails with the contention status"
  if ! grep -Fq "another profile transition is in progress: $tmpdir/profile.lock" \
    "$contender_output"; then
    printf 'FAIL: lock contention message does not name the lock path\n' >&2
    cat "$contender_output" >&2
    exit 1
  fi

  touch "$hook/release"
  wait "$first_pid"

  assert_eq old "$(cat "$profiles/active")" \
    "contention owner preserves the active profile"
  assert_eq light "$(cat "$profiles/active-variant")" \
    "only the lock owner applies its toggle"
  assert_eq light "$(cat "$profiles/variant-old")" \
    "the failed contender does not apply a second toggle"
}

check_post_commit_adapter_isolation() {
  local output="$tmpdir/post-commit-adapter.out"

  printf 'old\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'light\n' > "$profiles/variant-new"
  printf 'off\n' > "$profiles/focus"
  ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  printf 'started\n' > "$bar_state"
  printf 'mako\n' > "$notification_state"
  : > "$log"

  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    XDG_STATE_HOME="$tmpdir/state" PROFILE_TRANSITION_GSETTINGS_ERROR=1 \
    PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
    BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
    "$REPO_ROOT/home/scripts/profile-transition" switch new >"$output" 2>&1

  assert_eq new "$(cat "$profiles/active")" \
    "application adapter failure preserves the committed profile"
  assert_eq light "$(cat "$profiles/active-variant")" \
    "application adapter failure preserves the committed variant"
  assert_eq "$profiles/new/niri-overrides.kdl" \
    "$(readlink "$profiles/active-niri-overrides.kdl")" \
    "application adapter failure preserves the committed Niri override"
  assert_eq started "$(cat "$bar_state")" \
    "application adapter failure preserves the committed bar"
  assert_log_contains 'notify-send Desktop Profile Switched to new' \
    "a failed application adapter does not prevent later adapters"
  if ! grep -Fq 'system-preferences: gsettings: schema unavailable' "$output"; then
    printf 'FAIL: application adapter failure warning was not summarized\n' >&2
    cat "$output" >&2
    exit 1
  fi
  detail_path=$(sed -n 's/.*details: \([^)]*\)).*/\1/p' "$output")
  [ -f "$detail_path" ] || { printf 'FAIL: adapter detail log was not retained\n' >&2; exit 1; }
  assert_eq 600 "$(stat -c %a "$detail_path")" "adapter detail log permissions"
  grep -Fq 'full diagnostic line' "$detail_path" || {
    printf 'FAIL: adapter detail log omitted complete stderr\n' >&2
    exit 1
  }
}

check_status_accepts_runtime_niri() {
  local output="$tmpdir/profile-status.out"

  printf 'qs\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'off\n' > "$profiles/focus"
  "$real_jq" '.capabilities.wallpaperTheming = true' "$profiles/qs/manifest.json" \
    > "$profiles/qs/manifest.json.tmp"
  mv "$profiles/qs/manifest.json.tmp" "$profiles/qs/manifest.json"
  cp "$profiles/qs/niri-overrides.kdl" "$profiles/runtime-niri-active.kdl"
  ln -sfn "$profiles/runtime-niri-active.kdl" "$profiles/active-niri-overrides.kdl"
  printf 'quickshell-started\n' > "$bar_state"
  printf 'quickshell\n' > "$notification_state"

  HOME="$home" XDG_CONFIG_HOME="$home/.config" COMMAND_LOG="$log" \
    BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
    "$REPO_ROOT/home/scripts/switch-profile" --status > "$output" 2>&1 || true
  "$real_jq" '.capabilities.wallpaperTheming = false' "$profiles/qs/manifest.json" \
    > "$profiles/qs/manifest.json.tmp"
  mv "$profiles/qs/manifest.json.tmp" "$profiles/qs/manifest.json"
  if ! grep -Fq '[ok]      niri overrides symlink' "$output"; then
    printf 'FAIL: status rejected the wallpaper-generated Niri override\n' >&2
    cat "$output" >&2
    exit 1
  fi
}

check_snapshot_failure() {
  local failure="$1" expected_status="$2" before after status runtime_dir
  runtime_dir="$tmpdir/runtime-$failure"
  mkdir -p "$runtime_dir"
  printf 'started\n' > "$bar_state"
  : > "$log"
  before=$(tar -C "$home" -cf - . | sha256sum)
  set +e
  HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_RUNTIME_DIR="$runtime_dir" \
    PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
    BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
    PROFILE_TRANSITION_FAIL_SNAPSHOT="$failure" \
    "$REPO_ROOT/home/scripts/profile-transition" switch new >"$runtime_dir/output" 2>&1
  status=$?
  set -e
  if [ "$expected_status" != "$status" ]; then
    cat "$runtime_dir/output" >&2
  fi
  rm -f "$runtime_dir/output"
  assert_eq "$expected_status" "$status" "$failure snapshot failure is propagated"
  after=$(tar -C "$home" -cf - . | sha256sum)
  assert_eq "$before" "$after" "$failure snapshot failure occurs before mutation"
  if find "$runtime_dir" -mindepth 1 -print -quit | grep -q .; then
    printf 'FAIL: %s snapshot failure left a transaction directory behind\n' "$failure" >&2
    exit 1
  fi
}

check_snapshot_signal_cleanup() {
  local before after status runtime_dir="$tmpdir/runtime-signal"
  mkdir -p "$runtime_dir"
  before=$(tar -C "$home" -cf - . | sha256sum)
  set +e
  HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_RUNTIME_DIR="$runtime_dir" \
    PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
    BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
    PROFILE_TRANSITION_SIGNAL_DURING_SNAPSHOT=TERM \
    "$REPO_ROOT/home/scripts/profile-transition" switch new >/dev/null 2>&1
  status=$?
  set -e
  assert_eq 143 "$status" "snapshot signal preserves the conventional status"
  after=$(tar -C "$home" -cf - . | sha256sum)
  assert_eq "$before" "$after" "snapshot signal occurs before mutation"
  if find "$runtime_dir" -mindepth 1 -print -quit | grep -q .; then
    printf 'FAIL: snapshot signal left a transaction directory behind\n' >&2
    exit 1
  fi
}

check_unusual_snapshot_paths() {
  local odd_file odd_link odd_target runtime_dir status
  odd_file="$home/.config/odd"$'\tline\nfile'
  odd_link="$home/.config/odd-link"$'\n'
  odd_target=$'target\tline\n'
  runtime_dir="$tmpdir/runtime-unusual"
  printf 'original unusual bytes\n' > "$odd_file"
  ln -s -- "$odd_target" "$odd_link"
  mkdir -p "$runtime_dir"
  set +e
  HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_RUNTIME_DIR="$runtime_dir" \
    PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
    BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
    PROFILE_TRANSITION_TEST_FILE_PATH="$odd_file" \
    PROFILE_TRANSITION_TEST_SYMLINK_PATH="$odd_link" \
    PROFILE_TRANSITION_TEST_MUTATE_SNAPSHOTS=1 \
    "$REPO_ROOT/home/scripts/profile-transition" switch new >/dev/null 2>&1
  status=$?
  set -e
  assert_eq 29 "$status" "unusual path rollback preserves original status"
  assert_eq "original unusual bytes" "$(cat "$odd_file")" \
    "tab and newline file path round-trips"
  if ! cmp -s <(printf '%s\0' "$odd_target") <(readlink -z -- "$odd_link"); then
    printf 'FAIL: trailing-newline symlink target did not round-trip\n' >&2
    exit 1
  fi
}

check_legacy_runtime_regressions() {
  local active_stat variant_stat preference_stat output="$tmpdir/legacy-runtime.out"
  local previous_digest="" previous_log="" suite_log="$log"
  local adapter_children="$tmpdir/legacy-adapter-children"

  mkdir -p "$adapter_children"

  run_legacy_transition() {
    local name="$1" completion
    shift
    if [ -n "$previous_log" ]; then
      assert_eq "$previous_digest" "$(sha256sum "$previous_log")" \
        "completed legacy scenario log remains immutable"
    fi
    log="$tmpdir/legacy-$name.log"
    completion="$tmpdir/legacy-$name.complete"
    : > "$log"
    rm -f "$completion"
    PROFILE_TRANSITION_TEST_SYNC_ASYNC=1 \
      PROFILE_TRANSITION_TEST_COMPLETION_FILE="$completion" \
      FIXTURE_ADAPTER_CHILD_DIR="$adapter_children" \
      run_fixture_transition "$@" >"$output" 2>&1
    [ -e "$completion" ] || {
      printf 'FAIL: legacy scenario %s did not signal adapter completion\n' "$name" >&2
      exit 1
    }
    if find "$adapter_children" -mindepth 1 -print -quit | grep -q .; then
      printf 'FAIL: legacy scenario %s completed with a post-commit child running\n' \
        "$name" >&2
      exit 1
    fi
    previous_log="$log"
    previous_digest=$(sha256sum "$previous_log")
  }

  printf 'missing\n' > "$profiles/active"
  printf 'light\n' > "$profiles/active-variant"
  printf 'light\n' > "$profiles/variant-noctalia"
  ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  printf 'noctalia-started\n' > "$bar_state"
  printf 'noctalia\n' > "$notification_state"
  run_legacy_transition invalid-startup startup
  assert_eq noctalia "$(cat "$profiles/active")" \
    "invalid startup fallback repairs the active preference"
  assert_eq dark "$(cat "$profiles/active-variant")" \
    "invalid startup fallback repairs the global variant preference"
  assert_eq dark "$(cat "$profiles/variant-noctalia")" \
    "invalid startup fallback repairs the Noctalia variant preference"
  assert_eq "$profiles/noctalia/niri-overrides.kdl" \
    "$(readlink "$profiles/active-niri-overrides.kdl")" \
    "invalid startup falls back to Noctalia runtime"

  printf 'old\n' > "$profiles/active"
  printf 'light\n' > "$profiles/active-variant"
  printf 'dark\n' > "$profiles/variant-old"
  ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  printf 'started\n' > "$bar_state"
  printf 'mako\n' > "$notification_state"
  active_stat=$(stat -c '%i:%Y' "$profiles/active")
  variant_stat=$(stat -c '%i:%Y' "$profiles/active-variant")
  preference_stat=$(stat -c '%i:%Y' "$profiles/variant-old")
  run_legacy_transition valid-startup startup
  assert_eq '* { color: old-light; }' "$(cat "$home/.config/waybar/style.css")" \
    "startup reapplies the valid active variant"
  assert_eq old "$(cat "$profiles/active")" \
    "valid startup preserves the active preference"
  assert_eq light "$(cat "$profiles/active-variant")" \
    "valid startup preserves the global variant preference"
  assert_eq dark "$(cat "$profiles/variant-old")" \
    "valid startup does not rewrite the per-profile preference"
  assert_eq "$active_stat" "$(stat -c '%i:%Y' "$profiles/active")" \
    "valid startup does not replace the active preference file"
  assert_eq "$variant_stat" "$(stat -c '%i:%Y' "$profiles/active-variant")" \
    "valid startup does not replace the global variant preference file"
  assert_eq "$preference_stat" "$(stat -c '%i:%Y' "$profiles/variant-old")" \
    "valid startup does not replace the per-profile preference file"

  printf 'quickshell\n' > "$profiles/bar-old"
  printf 'old\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'dark\n' > "$profiles/variant-old"
  ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  printf 'started\n' > "$bar_state"
  printf 'mako\n' > "$notification_state"
  run_legacy_transition reapply-override reapply
  assert_log_contains 'systemctl --user stop noctalia-shell' \
    "reapply stops Noctalia when a bar override may have changed"
  assert_log_contains 'pkill -f waybar' \
    "reapply stops Waybar when a bar override may have changed"
  assert_log_contains "pkill -f quickshell.*$REPO_ROOT/home/configs/quickshell/shell.qml" \
    "reapply stops Quickshell when a bar override may have changed"
  rm -f "$profiles/bar-old"

  printf 'on\n' > "$profiles/focus"
  printf 'old\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'dark\n' > "$profiles/variant-new"
  ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  printf 'started\n' > "$bar_state"
  printf 'mako\n' > "$notification_state"
  run_legacy_transition focus-on switch new
  assert_eq "$profiles/new/niri-overrides-focus.kdl" \
    "$(readlink "$profiles/active-niri-overrides.kdl")" \
    "focus mode selects the target focus override"

  printf 'dark\n' > "$profiles/variant-noctalia"
  run_legacy_transition focus-noctalia switch noctalia
  assert_eq "$profiles/noctalia/niri-overrides.kdl" \
    "$(readlink "$profiles/active-niri-overrides.kdl")" \
    "focus mode keeps Noctalia on its normal override"
  assert_log_contains_eventually \
    "noctalia-shell ipc --any-display call wallpaper random eDP-1 active=noctalia" \
    "self-themed Noctalia dispatches wallpaper selection through shell IPC"

  printf 'off\n' > "$profiles/focus"
  printf 'dark\n' > "$profiles/variant-old"
  run_legacy_transition focus-off-static switch old
  assert_eq "$profiles/old/niri-overrides.kdl" \
    "$(readlink "$profiles/active-niri-overrides.kdl")" \
    "non-Noctalia target uses its normal override outside focus mode"
  assert_log_contains_eventually \
    "awww img $profiles/old/wallpapers/wallpaper.png --transition-type fade --transition-duration 1 active=old" \
    "static profile selects a wallpaper after commit"
  assert_log_contains_eventually \
    "quickshell -p $REPO_ROOT/home/configs/quickshell-switcher/shell.qml active=old" \
    "transition starts the profile switcher popup"

  "$real_jq" '.capabilities.wallpaperTheming = true' "$profiles/new/manifest.json" \
    > "$profiles/new/manifest.json.tmp"
  mv "$profiles/new/manifest.json.tmp" "$profiles/new/manifest.json"
  mkdir -p "$home/.config/matugen"
  printf 'fixture\n' > "$home/.config/matugen/config-new.toml"
  printf 'light\n' > "$profiles/variant-new"
  printf 'quickshell\n' > "$profiles/bar-new"
  run_legacy_transition wallpaper-themed switch new
  assert_log_contains_eventually \
    "matugen color hex #6c7a89 --mode light --type scheme-tonal-spot -c $home/.config/matugen/config-new.toml active=new" \
    "wallpaper-themed profile dispatches its runtime palette adapter after commit"
  assert_log_not_contains \
    "pkill -f quickshell.*$REPO_ROOT/home/configs/quickshell/shell.qml" \
    "wallpaper theme does not kill Quickshell to repaint"
  # After switch from waybar→quickshell there is exactly one topbar launch from start_bar;
  # wallpaper theming must not launch shell.qml again.
  launch_count=$(grep -c "quickshell -p $REPO_ROOT/home/configs/quickshell/shell.qml " "$log" || true)
  assert_eq "1" "$launch_count" \
    "wallpaper theme does not relaunch Quickshell after start_bar"
  [ -s "$profiles/quickshell-theme-reload" ] \
    || { printf 'FAIL: missing quickshell-theme-reload stamp after wallpaper theme\n' >&2; exit 1; }
  assert_eq "$previous_digest" "$(sha256sum "$previous_log")" \
    "final completed legacy scenario log remains immutable"
  log="$suite_log"
}

mkdir -p "$profiles" "$bin_dir" "$home/.config/waybar" "$persistent_pid_dir"

for utility in awk bash basename cat chmod cp cut dirname env find flock grep head install ln mkdir \
  mktemp mv paste readlink realpath rm rmdir sed seq sha256sum shuf sleep sort stat tail tar touch tr xargs; do
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
  printf 'gtk-%s-dark\n' "$profile" > "$profile_dir/gtk-3.0.css"
  printf 'gtk-%s-light\n' "$profile" > "$profile_dir/gtk-3.0-light.css"
  printf 'gtk4-%s-dark\n' "$profile" > "$profile_dir/gtk-4.0.css"
  printf 'gtk4-%s-light\n' "$profile" > "$profile_dir/gtk-4.0-light.css"
  printf 'qt-%s-dark\n' "$profile" > "$profile_dir/qt6ct.conf"
  printf 'qt-%s-light\n' "$profile" > "$profile_dir/qt6ct-light.conf"
  printf 'rofi-%s-dark\n' "$profile" > "$profile_dir/rofi-theme.rasi"
  printf 'rofi-%s-light\n' "$profile" > "$profile_dir/rofi-theme-light.rasi"
  printf 'fish-%s-dark\n' "$profile" > "$profile_dir/fish-theme.fish"
  printf 'fish-%s-light\n' "$profile" > "$profile_dir/fish-theme-light.fish"
  printf 'starship-%s-dark\n' "$profile" > "$profile_dir/starship.toml"
  printf 'starship-%s-light\n' "$profile" > "$profile_dir/starship-light.toml"
  printf 'layout { gaps 8; }\n' > "$profile_dir/niri-overrides.kdl"
  printf '{"profile":"%s"}\n' "$profile" > "$profile_dir/waybar-config.jsonc"
  printf '* { color: %s-dark; }\n' "$profile" > "$profile_dir/waybar-style.css"
  printf '* { color: %s-light; }\n' "$profile" > "$profile_dir/waybar-style-light.css"
  printf 'font=old 8\nprofile=%s-dark\n' "$profile" > "$profile_dir/mako-config"
  printf 'font=old 8\nprofile=%s-light\n' "$profile" > "$profile_dir/mako-config-light"
  printf '%s\n' "$wallpaper_dir" > "$profile_dir/wallpaper-dir"
  printf '%s\n' "$wallpaper_dir" > "$profile_dir/wallpaper-dir-light"
  touch "$wallpaper_dir/wallpaper.png"
done

for profile in old new; do
  "$real_jq" '.fonts = {ui: {family: "Fixture UI", size: 12}, mono: {family: "Fixture Mono", size: 15}}
    | .appearance = {gtkTheme: "fixture-dark", gtkThemeLight: "fixture-light", iconTheme: "fixture-icons-dark", iconThemeLight: "fixture-icons-light", kittyOpacity: 0.8}
    | .cursor = "fixture-cursor" | .cursorSize = 28' \
    "$profiles/$profile/meta.json" > "$profiles/$profile/meta.json.tmp"
  mv "$profiles/$profile/meta.json.tmp" "$profiles/$profile/meta.json"
  wallpaper_dir="$profiles/$profile/wallpapers"
  "$real_jq" -n --arg name "$profile" --arg wallpaper "$wallpaper_dir" '
    {
      schemaVersion: 1,
      name: $name,
      capabilities: {
        selfThemed: false, wallpaperTheming: false, colorEngine: "matugen",
        matugenScheme: "scheme-tonal-spot", wallpaperAccentVivid: false,
        obsidianWallpaperTheme: false
      },
      transition: {
        defaultBar: "waybar",
        cursor: {theme: "fixture-cursor", size: 28},
        fonts: {ui: {family: "Fixture UI", size: 12}, mono: {family: "Fixture Mono", size: 15}},
        appearance: {gtkTheme: "fixture-dark", gtkThemeLight: "fixture-light", iconTheme: "fixture-icons-dark", iconThemeLight: "fixture-icons-light", kittyOpacity: 0.8}
      },
      variants: {
        dark: {wallpaperDirectory: $wallpaper, adapters: {}, artifacts: {kitty: "kitty-colors.conf", gtk3: "gtk-3.0.css", gtk4: "gtk-4.0.css", qt6: "qt6ct.conf", rofi: "rofi-theme.rasi", fish: "fish-theme.fish", starship: "starship.toml"}},
        light: {wallpaperDirectory: $wallpaper, adapters: {}, artifacts: {kitty: "kitty-colors-light.conf", gtk3: "gtk-3.0-light.css", gtk4: "gtk-4.0-light.css", qt6: "qt6ct-light.conf", rofi: "rofi-theme-light.rasi", fish: "fish-theme-light.fish", starship: "starship-light.toml"}}
      },
      artifacts: {
        niri: {default: "niri-overrides.kdl", focus: "niri-overrides-focus.kdl"},
        waybar: {config: "waybar-config.jsonc", dark: "waybar-style.css", light: "waybar-style-light.css"},
        mako: {dark: "mako-config", light: "mako-config-light"}
      }
    }' > "$profiles/$profile/manifest.json"
  rm "$profiles/$profile/meta.json" "$profiles/$profile/runtime.json" \
    "$profiles/$profile/wallpaper-dir" "$profiles/$profile/wallpaper-dir-light"
done

cp -a "$profiles/old" "$profiles/qs"
"$real_jq" '.name = "qs" | .transition.defaultBar = "quickshell"
  | .artifacts.quickshell = {dark: "quickshell-theme.json", light: "quickshell-theme-light.json"}' \
  "$profiles/qs/manifest.json" > "$profiles/qs/manifest.json.tmp"
mv "$profiles/qs/manifest.json.tmp" "$profiles/qs/manifest.json"
printf '{"payload":"qs-dark"}\n' > "$profiles/qs/quickshell-theme.json"
printf '{"payload":"qs-light"}\n' > "$profiles/qs/quickshell-theme-light.json"
cp -a "$profiles/old" "$profiles/noc"
"$real_jq" '.name = "noc" | .transition.defaultBar = "noctalia"
  | .capabilities.selfThemed = true | del(.variants.light)' \
  "$profiles/noc/manifest.json" > "$profiles/noc/manifest.json.tmp"
mv "$profiles/noc/manifest.json.tmp" "$profiles/noc/manifest.json"
cp -a "$profiles/noc" "$profiles/noctalia"
"$real_jq" '.name = "noctalia"' "$profiles/noctalia/manifest.json" \
  > "$profiles/noctalia/manifest.json.tmp"
mv "$profiles/noctalia/manifest.json.tmp" "$profiles/noctalia/manifest.json"
printf 'layout { gaps 4; }\n' > "$profiles/noctalia/niri-overrides-focus.kdl"
for profile in old new qs noc; do
  printf 'layout { gaps 4; }\n' > "$profiles/$profile/niri-overrides-focus.kdl"
done

mkdir -p "$home/.config/gtk-3.0" "$home/.config/gtk-4.0" \
  "$home/.config/qt5ct/colors" "$home/.config/qt6ct/colors" "$home/.config/kitty" \
  "$home/.config/mako"
printf '[Settings]\ngtk-font-name=Old 9\ngtk-theme-name=old-theme\ngtk-cursor-theme-name=old-cursor\n' \
  > "$home/.config/gtk-3.0/settings.ini"
cp "$home/.config/gtk-3.0/settings.ini" "$home/.config/gtk-4.0/settings.ini"
printf 'font_family family="Old Mono"\nfont_size 9\nbackground_opacity 1.0\n' \
  > "$home/.config/kitty/kitty.conf"
cp "$profiles/old/waybar-config.jsonc" "$home/.config/waybar/config.jsonc"
cp "$profiles/old/waybar-style.css" "$home/.config/waybar/style.css"
cp "$profiles/old/mako-config" "$home/.config/mako/config"
chmod 640 "$home/.config/waybar/config.jsonc"

printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-old"
printf 'light\n' > "$profiles/variant-new"
ln -s "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'mako\n' > "$notification_state"

for command in systemctl niri quickshell gsettings notify-send busctl awww mpvpaper mako makoctl tmux kitty magick matugen noctalia-shell; do
  cat > "$bin_dir/$command" <<'EOF'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "$COMMAND_LOG"
if [ "$(basename "$0")" = gsettings ] && [ -n "${PROFILE_TRANSITION_GSETTINGS_ERROR:-}" ]; then
  printf 'gsettings: schema unavailable\nfull diagnostic line\n' >&2
  exit 1
fi
case "$(basename "$0") $*" in
  "systemctl --user is-active"*) printf 'active\n' ;;
esac
EOF
done

cat > "$bin_dir/niri" <<'EOF'
#!/usr/bin/env bash
printf 'niri %s\n' "$*" >> "$COMMAND_LOG"
if [ "$*" = 'msg outputs' ]; then
  printf 'Output "eDP-1" (eDP-1)\n'
fi
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
    if ! { [ -n "${IGNORE_FIRST_NOCTALIA_STOP:-}" ] && [ "${count:-0}" -eq 1 ]; }; then
      printf 'stopped\n' > "$BAR_STATE"
      [ "$(cat "$NOTIFICATION_STATE")" != noctalia ] || printf 'none\n' > "$NOTIFICATION_STATE"
    fi
    ;;
  *" start noctalia-shell "*)
    printf 'noctalia-started\n' > "$BAR_STATE"
    [ -n "${FAIL_NOTIFICATION_OWNER:-}" ] || printf 'noctalia\n' > "$NOTIFICATION_STATE"
    ;;
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
  *" \\.?mako(-wrapped)? "*)
    if [ -n "${MAKO_STOP_POLLS:-}" ]; then
      printf 'mako-stopping:%s\n' "$MAKO_STOP_POLLS" > "$NOTIFICATION_STATE"
    else
      printf 'none\n' > "$NOTIFICATION_STATE"
    fi
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
if [ -n "${PERSISTENT_CHILDREN:-}" ]; then
  mkdir -p "$PERSISTENT_PID_DIR"
  pid_file="$PERSISTENT_PID_DIR/waybar"
  printf '%s\n' "$$" > "$pid_file"
  trap 'rm -f "$pid_file"' EXIT
  sleep 5
fi
EOF

cat > "$bin_dir/quickshell" <<'EOF'
#!/usr/bin/env bash
active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
active_variant=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active-variant" 2>/dev/null || echo dark)
theme_profile=${DESKTOP_PROFILE_TRANSITION_TARGET:-$active}
theme_variant=${DESKTOP_PROFILE_TRANSITION_VARIANT:-$active_variant}
selected=$("$PROFILE_THEME_SELECTOR")
printf 'quickshell %s active=%s active_variant=%s theme=%s theme_variant=%s selected=%s\n' \
  "$*" "$active" "$active_variant" "$theme_profile" "$theme_variant" "$selected" >> "$COMMAND_LOG"
if [ -n "${START_COUNT_FILE:-}" ]; then
  count=$(cat "$START_COUNT_FILE" 2>/dev/null || echo 0)
  printf '%s\n' "$((count + 1))" > "$START_COUNT_FILE"
fi
child_file=""
if [ -n "${PROFILE_TRANSITION_TEST_POST_COMMIT:-}" ] \
  && [ -n "${FIXTURE_ADAPTER_CHILD_DIR:-}" ]; then
  mkdir -p "$FIXTURE_ADAPTER_CHILD_DIR"
  child_file="$FIXTURE_ADAPTER_CHILD_DIR/$$"
  printf '%s\n' "$*" > "$child_file"
  trap 'rm -f "$child_file"' EXIT
  sleep 0.1
fi
case "$*" in
  *quickshell-switcher/shell.qml*) exit 0 ;;
esac
if [ "$(cat "$NOTIFICATION_STATE")" = none ] && [ -z "${FAIL_NOTIFICATION_OWNER:-}" ]; then
  printf 'quickshell-started\n' > "$BAR_STATE"
  printf 'quickshell\n' > "$NOTIFICATION_STATE"
fi
if [ -n "${PERSISTENT_CHILDREN:-}" ]; then
  mkdir -p "$PERSISTENT_PID_DIR"
  pid_file="$PERSISTENT_PID_DIR/quickshell"
  printf '%s\n' "$$" > "$pid_file"
  trap 'rm -f "$pid_file"' EXIT
  sleep 5
fi
EOF

cat > "$bin_dir/awww" <<'EOF'
#!/usr/bin/env bash
active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
printf 'awww %s active=%s\n' "$*" "$active" >> "$COMMAND_LOG"
EOF

for command in matugen noctalia-shell; do
  cat > "$bin_dir/$command" <<'EOF'
#!/usr/bin/env bash
active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
printf '%s %s active=%s\n' "$(basename "$0")" "$*" "$active" >> "$COMMAND_LOG"
EOF
done

cat > "$bin_dir/mako" <<'EOF'
#!/usr/bin/env bash
printf 'mako %s\n' "$*" >> "$COMMAND_LOG"
[ -n "${FAIL_NOTIFICATION_OWNER:-}" ] || printf 'mako\n' > "$NOTIFICATION_STATE"
if [ -n "${PERSISTENT_CHILDREN:-}" ]; then
  mkdir -p "$PERSISTENT_PID_DIR"
  pid_file="$PERSISTENT_PID_DIR/mako"
  printf '%s\n' "$$" > "$pid_file"
  trap 'rm -f "$pid_file"' EXIT
  sleep 5
fi
EOF

cat > "$bin_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
active=$(cat "$XDG_CONFIG_HOME/desktop-profiles/active")
state=$(cat "$BAR_STATE")
if [[ " $* " == *" \\.?mako(-wrapped)? "* ]]; then
  notification=$(cat "$NOTIFICATION_STATE")
  case "$notification" in
    mako)
      printf 'pgrep-mako active\n' >> "$COMMAND_LOG"
      exit 0
      ;;
    mako-stopping:*)
      polls=${notification##*:}
      printf 'pgrep-mako stopping=%s\n' "$polls" >> "$COMMAND_LOG"
      if [ "$polls" -gt 1 ]; then
        printf 'mako-stopping:%s\n' "$((polls - 1))" > "$NOTIFICATION_STATE"
        exit 0
      fi
      printf 'none\n' > "$NOTIFICATION_STATE"
      exit 1
      ;;
    *) exit 1 ;;
  esac
fi
if [ -n "${FAIL_FIRST_BAR_START:-}" ] && [ "$(cat "$START_COUNT_FILE" 2>/dev/null || echo 0)" = 1 ]; then
  printf 'pgrep %s active=%s state=%s\n' "$*" "$active" "$state" >> "$COMMAND_LOG"
  exit 1
fi
case " $* :$state" in
  *" waybar "*:started)
    printf 'pgrep %s\n' "$*" >> "$COMMAND_LOG"
    printf 'verify-waybar active=%s\n' "$active" >> "$COMMAND_LOG"
    exit 0
    ;;
  *" quickshell"*"quickshell/shell.qml"*:quickshell-started)
    printf 'pgrep %s\n' "$*" >> "$COMMAND_LOG"
    printf 'verify-quickshell active=%s\n' "$active" >> "$COMMAND_LOG"
    exit 0
    ;;
  *)
    printf 'pgrep %s active=%s state=%s\n' "$*" "$active" "$state" >> "$COMMAND_LOG"
    exit 1
    ;;
esac
EOF

cat > "$bin_dir/busctl" <<'EOF'
#!/usr/bin/env bash
printf 'busctl %s\n' "$*" >> "$COMMAND_LOG"
[ "$*" = '--user status org.freedesktop.Notifications' ] || exit 1
case "$(cat "$NOTIFICATION_STATE")" in
  mako | mako-stopping:*) printf 'mako notification server\n' ;;
  quickshell) printf 'quickshell notification server\n' ;;
  noctalia) printf 'noctalia-shell notification server\n' ;;
  *) exit 1 ;;
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
assert_log_contains "verify-waybar active=old" \
  "post-start target bar readiness is verified before active profile commit"
assert_eq '* { color: new-light; }' "$(cat "$home/.config/waybar/style.css")" \
  "old-to-new Waybar switch installs the target variant style"
assert_eq 'font=Fixture UI 12
profile=new-light' "$(cat "$home/.config/mako/config")" \
  "old-to-new Waybar switch transforms the target Mako config"

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
assert_log_not_contains "pkill -f waybar" "staging failure occurs before old Waybar shutdown"
assert_log_not_contains "verify-waybar active=old" "staging failure needs no bar recovery"
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
  PROFILE_TRANSITION_FAIL_INSTALL_PATH="$home/.config/waybar/style.css" \
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

# Once all preferences are durable, a signal may clean transaction storage but
# must not roll the committed state or runtime back.
printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'light\n' > "$profiles/variant-new"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
cp "$profiles/old/waybar-config.jsonc" "$home/.config/waybar/config.jsonc"
cp "$profiles/old/waybar-style.css" "$home/.config/waybar/style.css"
printf 'started\n' > "$bar_state"
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

# Every previous/target bar pairing follows one bar policy. Target readiness is
# checked before preferences commit, and notification/wallpaper ownership tracks
# the target rather than the previous bar.
printf 'on\n' > "$profiles/focus"
for previous in old qs noc; do
  case "$previous" in
    old) previous_state=started ;;
    qs) previous_state=quickshell-started ;;
    noc) previous_state=noctalia-started ;;
  esac
  for target in old qs noc; do
    printf '%s\n' "$previous" > "$profiles/active"
    printf 'dark\n' > "$profiles/active-variant"
    printf 'dark\n' > "$profiles/variant-$target"
    ln -sfn "$profiles/$previous/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
    printf '%s\n' "$previous_state" > "$bar_state"
    : > "$log"
    HOME="$home" XDG_CONFIG_HOME="$home/.config" \
      PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
      BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
      "$REPO_ROOT/home/scripts/profile-transition" switch "$target"

    case "$previous" in
      old) assert_log_contains 'pkill -f waybar' "Waybar is stopped from $previous to $target" ;;
      qs) assert_log_contains "pkill -f quickshell.*$REPO_ROOT/home/configs/quickshell/shell.qml" \
        "Quickshell exact topbar is stopped from $previous to $target" ;;
      noc) assert_log_contains 'systemctl --user stop noctalia-shell' \
        "Noctalia is stopped from $previous to $target" ;;
    esac
    case "$target" in
      old)
        assert_log_contains 'pgrep -f waybar' "Waybar readiness uses pgrep from $previous"
        assert_log_contains 'systemctl --user start awww' "Waybar starts awww from $previous"
        assert_log_contains_eventually 'mako ' "Waybar starts Mako from $previous"
        assert_log_contains 'makoctl mode -a dnd' "Waybar rearms focus DND from $previous"
        assert_log_contains 'busctl --user status org.freedesktop.Notifications' \
          "Waybar verifies notification ownership from $previous"
        ;;
      qs)
        assert_log_contains "pgrep -f quickshell.*$REPO_ROOT/home/configs/quickshell/shell.qml" \
          "Quickshell readiness uses the exact topbar from $previous"
        assert_log_contains 'systemctl --user start awww' "Quickshell starts awww from $previous"
        assert_log_contains "pkill -x \\.?mako(-wrapped)?" "Quickshell stops Mako from $previous"
        assert_log_not_contains 'makoctl mode -a dnd' "Quickshell does not rearm focus DND from $previous"
        assert_log_contains 'busctl --user status org.freedesktop.Notifications' \
          "Quickshell verifies notification ownership from $previous"
        ;;
      noc)
        assert_log_contains 'systemctl --user is-active --quiet noctalia-shell' \
          "Noctalia readiness uses systemctl from $previous"
        assert_log_contains 'systemctl --user stop awww' "Noctalia stops awww from $previous"
        assert_log_contains "pkill -x \\.?mako(-wrapped)?" "Noctalia stops Mako from $previous"
        assert_log_not_contains 'makoctl mode -a dnd' "Noctalia does not rearm focus DND from $previous"
        assert_log_contains 'busctl --user status org.freedesktop.Notifications' \
          "Noctalia verifies notification ownership from $previous"
        ;;
    esac
  done
done

assert_eq '{"profile":"old"}' "$(cat "$home/.config/waybar/config.jsonc")" \
  "Waybar config is installed as a writable target file"
assert_eq '* { color: old-dark; }' "$(cat "$home/.config/waybar/style.css")" \
  "Waybar style is installed as a writable target file"
assert_eq 'profile=old-dark' "$(tail -n 1 "$home/.config/mako/config")" \
  "Waybar Mako config is installed transactionally"
assert_mode 644 "$home/.config/waybar/config.jsonc" "Waybar config remains writable"
assert_mode 644 "$home/.config/waybar/style.css" "Waybar style remains writable"
assert_mode 644 "$home/.config/mako/config" "Mako config remains writable"
assert_eq 'gtk-old-dark' "$(cat "$home/.config/gtk-3.0/noctalia.css")" \
  "core GTK color file is installed"
assert_log_not_contains 'apply_vicinae' "core staging excludes best-effort application adapters"

# Quickshell cannot claim org.freedesktop.Notifications until Mako has released
# it. The transition must wait for that release rather than committing a bar
# process whose notification server never came up.
printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'light\n' > "$profiles/variant-qs"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'started\n' > "$bar_state"
printf 'mako\n' > "$notification_state"
printf '{"payload":"qs-runtime-dark"}\n' > "$profiles/runtime-quickshell-theme.json"
printf 'qs\n' > "$profiles/runtime-theme-profile"
rm -f "$profiles/runtime-theme-variant"
assert_eq '{"payload":"qs-dark"}' \
  "$(HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    DESKTOP_PROFILE_TRANSITION_TARGET=qs DESKTOP_PROFILE_TRANSITION_VARIANT=dark \
    "$PROFILE_THEME_SELECTOR")" \
  "an untagged legacy runtime override falls back to the baked dark theme"
printf 'dark\n' > "$profiles/runtime-theme-variant"
: > "$log"
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" MAKO_STOP_POLLS=3 \
  "$REPO_ROOT/home/scripts/profile-transition" switch qs
assert_eq quickshell "$(cat "$notification_state")" \
  "Quickshell starts only after Mako releases notification ownership"
assert_log_contains \
  "quickshell -p $REPO_ROOT/home/configs/quickshell/shell.qml active=old active_variant=dark theme=qs theme_variant=light selected={\"payload\":\"qs-light\"}" \
  "Quickshell selects the pending light payload instead of the stale dark runtime override"

printf 'qs\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-qs"
ln -sfn "$profiles/qs/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'quickshell-started\n' > "$bar_state"
printf 'quickshell\n' > "$notification_state"
: > "$log"
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  "$REPO_ROOT/home/scripts/profile-transition" variant light
assert_log_contains \
  "quickshell -p $REPO_ROOT/home/configs/quickshell/shell.qml active=qs active_variant=dark theme=qs theme_variant=light selected={\"payload\":\"qs-light\"}" \
  "Quickshell consumes the pending variant before variant commit"

printf 'dark\n' > "$profiles/active-variant"
printf 'dark\n' > "$profiles/variant-qs"
printf 'quickshell-started\n' > "$bar_state"
printf 'quickshell\n' > "$notification_state"
printf '0\n' > "$tmpdir/start-count"
: > "$log"
if HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  START_COUNT_FILE="$tmpdir/start-count" FAIL_FIRST_BAR_START=1 \
  "$REPO_ROOT/home/scripts/profile-transition" variant light >/dev/null 2>&1; then
  printf 'FAIL: Quickshell variant transition committed despite readiness failure\n' >&2
  exit 1
fi
assert_eq qs "$(cat "$profiles/active")" \
  "Quickshell rollback preserves the old active profile"
assert_eq dark "$(cat "$profiles/active-variant")" \
  "Quickshell rollback preserves the old active variant"
assert_log_contains \
  "quickshell -p $REPO_ROOT/home/configs/quickshell/shell.qml active=qs active_variant=dark theme=qs theme_variant=dark selected={\"payload\":\"qs-runtime-dark\"}" \
  "Quickshell rollback restarts the old dark runtime theme"

# A Waybar-to-Waybar transition must wait for the old Mako process to disappear
# before deciding whether to launch its replacement. A stale owner string is not
# enough: the replacement fake must remain alive after commit.
printf 'old\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'started\n' > "$bar_state"
printf 'mako\n' > "$notification_state"
rm -rf "$persistent_pid_dir"
mkdir -p "$persistent_pid_dir"
: > "$log"
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
  MAKO_STOP_POLLS=3 PERSISTENT_CHILDREN=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch new
for _ in $(seq 1 20); do
  [ -f "$persistent_pid_dir/mako" ] && break
  sleep 0.05
done
[ -f "$persistent_pid_dir/mako" ] || {
  printf 'FAIL: Waybar transition did not leave a replacement Mako running\n' >&2
  exit 1
}
assert_eq mako "$(cat "$notification_state")" \
  "Waybar replacement Mako owns notifications after commit"
stop_persistent_children

# A ready bar process is insufficient when its notification owner is absent.
printf 'noc\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
ln -sfn "$profiles/noc/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'noctalia-started\n' > "$bar_state"
printf 'noctalia\n' > "$notification_state"
: > "$log"
if HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" FAIL_NOTIFICATION_OWNER=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch old >/dev/null 2>&1; then
  printf 'FAIL: transition committed Waybar without its notification owner\n' >&2
  exit 1
fi
assert_eq noc "$(cat "$profiles/active")" \
  "notification ownership failure rolls back active profile"

# Spawned bars and notification daemons outlive the engine, but must not retain
# its flock file descriptor and block the next transition.
printf 'noc\n' > "$profiles/active"
printf 'dark\n' > "$profiles/active-variant"
ln -sfn "$profiles/noc/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
printf 'noctalia-started\n' > "$bar_state"
printf 'noctalia\n' > "$notification_state"
rm -rf "$persistent_pid_dir"
mkdir -p "$persistent_pid_dir"
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" PERSISTENT_CHILDREN=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch old
for _ in $(seq 1 20); do
  [ -f "$persistent_pid_dir/waybar" ] && [ -f "$persistent_pid_dir/mako" ] && break
  sleep 0.05
done
[ -f "$persistent_pid_dir/waybar" ] && [ -f "$persistent_pid_dir/mako" ] || {
  printf 'FAIL: persistent Waybar and Mako fakes did not remain running\n' >&2
  exit 1
}
if ! flock -n "$tmpdir/profile.lock" true; then
  printf 'FAIL: persistent bar child retained the transition lock\n' >&2
  exit 1
fi
stop_persistent_children

printf 'old\n' > "$profiles/active"
printf 'started\n' > "$bar_state"
printf 'mako\n' > "$notification_state"
mkdir -p "$persistent_pid_dir"
HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
  BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" PERSISTENT_CHILDREN=1 \
  "$REPO_ROOT/home/scripts/profile-transition" switch qs
for _ in $(seq 1 20); do
  [ -f "$persistent_pid_dir/quickshell" ] && break
  sleep 0.05
done
[ -f "$persistent_pid_dir/quickshell" ] || {
  printf 'FAIL: persistent Quickshell fake did not remain running\n' >&2
  exit 1
}
if ! flock -n "$tmpdir/profile.lock" true; then
  printf 'FAIL: persistent Quickshell child retained the transition lock\n' >&2
  exit 1
fi
stop_persistent_children

check_post_commit_adapter_isolation
check_status_accepts_runtime_niri
check_engine_variant_noops
check_variant_resolves_after_lock
check_lock_contention_is_nonblocking
check_public_delegation
check_legacy_runtime_regressions
