# shellcheck shell=bash
# Sourced by checks/profile-transition.bash; shares its globals.
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

assert_pending_cleared() {
  local label="$1"
  if [ -e "$profiles/transition-target" ] || [ -e "$profiles/transition-variant" ]; then
    printf 'FAIL: %s left pending transition identity files\n' "$label" >&2
    exit 1
  fi
}

home_visible_digest() {
  (
    cd "$home"
    find . -path './.config/desktop-profiles/theme-generation' -prune -o -type f -print0 | sort -z |
      xargs -0r sha256sum
    find . -type l -printf '%p -> %l\n' | sort
  ) | sha256sum
}

assert_selector_ignores_frozen_env() {
  local expected="$1" frozen_profile="$2" frozen_variant="$3" label="$4"
  assert_eq "$expected" \
    "$(HOME="$home" XDG_CONFIG_HOME="$home/.config" \
      DESKTOP_PROFILE_TRANSITION_TARGET="$frozen_profile" \
      DESKTOP_PROFILE_TRANSITION_VARIANT="$frozen_variant" \
      "$PROFILE_THEME_SELECTOR")" \
    "$label"
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

check_quickshell_readiness_fake() {
  printf 'stopped\n' > "$bar_state"
  : > "$log"
  if COMMAND_LOG="$log" BAR_STATE="$bar_state" XDG_CONFIG_HOME="$home/.config" PATH="$bin_dir" \
    "$bin_dir/pgrep" -f "quickshell.*quickshell/shell.qml"; then
    printf 'FAIL: stopped Quickshell reported ready\n' >&2
    exit 1
  fi
  if grep -Fq 'verify-quickshell' "$log"; then
    printf 'FAIL: stopped Quickshell emitted a readiness verification\n' >&2
    exit 1
  fi

  printf 'quickshell-started\n' > "$bar_state"
  COMMAND_LOG="$log" BAR_STATE="$bar_state" XDG_CONFIG_HOME="$home/.config" PATH="$bin_dir" \
    "$bin_dir/pgrep" -f "quickshell.*quickshell/shell.qml"
  assert_eq "verify-quickshell active=old" "$(tail -n 1 "$log")" \
    "started Quickshell emits the unique readiness verification"
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
  before=$(home_visible_digest)
  HOME="$home" XDG_CONFIG_HOME="$home/.config" COMMAND_LOG="$log" \
    ENGINE_LOG="$engine_log" REAL_JQ="$real_jq" PATH="$bin_dir" \
    "$adapter_dir/toggle-variant" dark >"$diagnostics" 2>&1
  assert_eq "profile-transition variant dark" "$(cat "$engine_log")" \
    "explicit current variant delegates its decision"
  after=$(home_visible_digest)
  assert_eq "$before" "$after" "explicit current variant leaves state untouched"
}
