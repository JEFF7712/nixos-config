# shellcheck shell=bash
# Sourced by checks/profile-transition.bash; shares its globals.
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
  before=$(home_visible_digest)
  if ! run_fixture_transition variant dark >"$output" 2>&1; then
    printf 'FAIL: explicit current variant exited nonzero\n' >&2
    cat "$output" >&2
    exit 1
  fi
  after=$(home_visible_digest)
  assert_eq "$before" "$after" "explicit current variant is an engine no-op"
  assert_log_not_contains 'niri msg action load-config-file' \
    "explicit current variant stops before core mutation"
}

check_startup_steady_state() {
  local output="$tmpdir/startup-steady.out"

  printf 'off\n' > "$profiles/focus"
  printf 'old\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'dark\n' > "$profiles/variant-old"
  ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  cp "$profiles/old/gtk-3.0.css" "$home/.config/gtk-3.0/noctalia.css"
  printf 'quickshell-started\n' > "$bar_state"
  printf 'quickshell\n' > "$notification_state"
  : > "$log"
  run_fixture_transition startup >"$output" 2>&1 || {
    printf 'FAIL: steady startup exited nonzero\n' >&2
    cat "$output" >&2
    exit 1
  }
  assert_eq old "$(cat "$profiles/active")" \
    "steady startup preserves the active profile"
  assert_eq dark "$(cat "$profiles/active-variant")" \
    "steady startup preserves the active variant"
  assert_eq "$profiles/old/niri-overrides.kdl" \
    "$(readlink "$profiles/active-niri-overrides.kdl")" \
    "steady startup leaves the Niri override linked"
  assert_log_contains "systemctl --user is-active --quiet quickshell-bar.service" \
    "steady startup verifies the running bar before leaving it alone"
  assert_log_not_contains "systemctl --user stop quickshell-bar.service" \
    "steady startup does not stop the running bar"
  assert_log_not_contains "systemctl --user start quickshell-bar.service" \
    "steady startup does not restart the running bar"
  assert_log_not_contains 'niri msg action load-config-file' \
    "steady startup does not reload Niri"
  assert_log_contains 'awww img' \
    "steady startup still refreshes the boot wallpaper"
  assert_pending_cleared "steady startup"

  printf 'off\n' > "$profiles/focus"
  printf 'old\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'dark\n' > "$profiles/variant-old"
  ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  printf 'stopped\n' > "$bar_state"
  printf 'none\n' > "$notification_state"
  : > "$log"
  run_fixture_transition startup >"$output" 2>&1 || {
    printf 'FAIL: steady startup with a stopped bar exited nonzero\n' >&2
    cat "$output" >&2
    exit 1
  }
  assert_log_contains "systemctl --user start quickshell-bar.service" \
    "steady startup with a stopped bar still starts it"
  assert_log_not_contains 'niri msg action load-config-file' \
    "steady bar start does not reload Niri"
  assert_eq quickshell-started "$(cat "$bar_state")" \
    "steady startup leaves the bar running"

  printf 'off\n' > "$profiles/focus"
  printf 'noc\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'dark\n' > "$profiles/variant-noc"
  ln -sfn "$profiles/noc/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  printf 'noctalia-started\n' > "$bar_state"
  printf 'noctalia\n' > "$notification_state"
  : > "$log"
  run_fixture_transition startup >"$output" 2>&1 || {
    printf 'FAIL: steady noctalia startup exited nonzero\n' >&2
    cat "$output" >&2
    exit 1
  }
  assert_log_not_contains 'systemctl --user stop noctalia-shell' \
    "steady noctalia startup does not stop the running shell"
  assert_log_not_contains 'systemctl --user start noctalia-shell' \
    "steady noctalia startup does not restart the running shell"
  assert_log_not_contains 'niri msg action load-config-file' \
    "steady noctalia startup does not reload Niri"
}

check_variant_resolves_after_lock() {
  local pid output="$tmpdir/variant-after-lock.out" hook="$tmpdir/variant-after-lock-hook"

  printf 'old\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'dark\n' > "$profiles/variant-old"
  ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  printf 'quickshell-started\n' > "$bar_state"
  printf 'quickshell\n' > "$notification_state"
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
  printf 'quickshell-started\n' > "$bar_state"
  printf 'quickshell\n' > "$notification_state"

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
  printf 'quickshell-started\n' > "$bar_state"
  printf 'quickshell\n' > "$notification_state"
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
  assert_eq quickshell-started "$(cat "$bar_state")" \
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
  printf 'quickshell-started\n' > "$bar_state"
  : > "$log"
  before=$(home_visible_digest)
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
  after=$(home_visible_digest)
  assert_eq "$before" "$after" "$failure snapshot failure occurs before mutation"
  if find "$runtime_dir" -mindepth 1 -print -quit | grep -q .; then
    printf 'FAIL: %s snapshot failure left a transaction directory behind\n' "$failure" >&2
    exit 1
  fi
}

check_snapshot_signal_cleanup() {
  local before after status runtime_dir="$tmpdir/runtime-signal"
  mkdir -p "$runtime_dir"
  before=$(home_visible_digest)
  set +e
  HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_RUNTIME_DIR="$runtime_dir" \
    PROFILE_TRANSITION_LOCK="$tmpdir/profile.lock" COMMAND_LOG="$log" \
    BAR_STATE="$bar_state" REAL_JQ="$real_jq" PATH="$bin_dir" \
    PROFILE_TRANSITION_SIGNAL_DURING_SNAPSHOT=TERM \
    "$REPO_ROOT/home/scripts/profile-transition" switch new >/dev/null 2>&1
  status=$?
  set -e
  assert_eq 143 "$status" "snapshot signal preserves the conventional status"
  after=$(home_visible_digest)
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
      run_fixture_transition "$@" >"$output" 2>&1 || {
      printf 'FAIL: legacy scenario %s transition exited %s\n' "$name" "$?" >&2
      cat "$output" >&2
      exit 1
    }
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
  printf 'quickshell-started\n' > "$bar_state"
  printf 'quickshell\n' > "$notification_state"
  active_stat=$(stat -c '%i:%Y' "$profiles/active")
  variant_stat=$(stat -c '%i:%Y' "$profiles/active-variant")
  preference_stat=$(stat -c '%i:%Y' "$profiles/variant-old")
  run_legacy_transition valid-startup startup
  assert_eq 'gtk-old-light' "$(cat "$home/.config/gtk-3.0/noctalia.css")" \
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

  printf 'old\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'dark\n' > "$profiles/variant-old"
  ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  printf 'quickshell-started\n' > "$bar_state"
  printf 'quickshell\n' > "$notification_state"
  run_legacy_transition reapply-override reapply
  assert_log_contains 'systemctl --user stop noctalia-shell' \
    "reapply stops Noctalia even when the target bar is Quickshell"
  assert_log_contains "systemctl --user stop quickshell-bar.service" \
    "reapply stops Quickshell so it can restart cleanly"

  printf 'on\n' > "$profiles/focus"
  printf 'old\n' > "$profiles/active"
  printf 'dark\n' > "$profiles/active-variant"
  printf 'dark\n' > "$profiles/variant-new"
  ln -sfn "$profiles/old/niri-overrides.kdl" "$profiles/active-niri-overrides.kdl"
  printf 'quickshell-started\n' > "$bar_state"
  printf 'quickshell\n' > "$notification_state"
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
    "noctalia msg wallpaper-random eDP-1 active=noctalia" \
    "self-themed Noctalia dispatches wallpaper selection through noctalia msg"
  assert_log_contains_eventually \
    "noctalia msg templates-apply active=noctalia" \
    "self-themed Noctalia reapplies templates after wallpaper selection"

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
  run_legacy_transition wallpaper-themed switch new
  if ! grep -Eq \
    'matugen color hex #6c7a89 --mode light --type scheme-tonal-spot -c .*/profile-theme-[0-9]+\.[^/]*/matugen\.toml active=new' \
    "$log"; then
    printf 'FAIL: wallpaper-themed profile did not render into a generation stage after commit\n' >&2
    cat "$log" >&2
    exit 1
  fi
  assert_log_not_contains \
    "systemctl --user stop quickshell-bar.service" \
    "wallpaper theme does not kill Quickshell to repaint"
  # qs→qs keeps the live topbar (SAME_QUICKSHELL); wallpaper theming must not
  # launch shell.qml as a side effect of the palette adapter.
  launch_count=$(grep -c "systemctl --user start quickshell-bar.service" "$log" || true)
  assert_eq "0" "$launch_count" \
    "wallpaper theme does not relaunch Quickshell after start_bar"
  [ -s "$profiles/quickshell-theme-reload" ] \
    || { printf 'FAIL: missing quickshell-theme-reload stamp after wallpaper theme\n' >&2; exit 1; }
  assert_eq "$previous_digest" "$(sha256sum "$previous_log")" \
    "final completed legacy scenario log remains immutable"
  log="$suite_log"
}
