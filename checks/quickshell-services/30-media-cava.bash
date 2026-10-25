# shellcheck shell=bash
# Sourced by checks/quickshell-services.bash; shares its globals.
run_media_service_probe() {
  local state_dir qs_pid rc=0 follow_pid follow_record real_jq
  printf 'quickshell-services: run_media_service_probe\n'
  state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-media-service.XXXXXX")
  fixture_state_dirs+=("$state_dir")
  mkdir -p "$state_dir/fixture-bin" "$state_dir/config/services/internal" "$state_dir/processes"
  ln -s "$audio_fixture_bin/playerctl" "$state_dir/fixture-bin/playerctl"
  ln -s "$audio_fixture_bin/jq" "$state_dir/fixture-bin/jq"
  cp "$media_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
  cp "$media_fixture_qml/policy.json" "$state_dir/policy.json"
  cp "$repo_root/home/configs/quickshell/services/AudioService.qml" "$state_dir/config/services/AudioService.qml"
  cp "$repo_root/home/configs/quickshell/services/MediaService.qml" "$state_dir/config/services/MediaService.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/AudioReducer.js" "$state_dir/config/services/internal/AudioReducer.js"
  cp "$repo_root/home/configs/quickshell/services/internal/AudioModel.qml" "$state_dir/config/services/internal/AudioModel.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/PipewireAudioBackend.qml" "$state_dir/config/services/internal/PipewireAudioBackend.qml"
  cp "$repo_root/home/configs/quickshell/services/internal/MediaParser.js" "$state_dir/config/services/internal/MediaParser.js"
  cp "$repo_root/home/configs/quickshell/services/internal/MediaModel.qml" "$state_dir/config/services/internal/MediaModel.qml"
  : >"$state_dir/actions.log"
  mkfifo "$state_dir/follow.fifo"
  jq -e '.selection == "bare playerctl default selection" and
    (.scenarios.onePlayer.state.available | type == "boolean") and
    (.scenarios.multipleDefaultPaused.state.players | length) >= 2 and
    .scenarios.multipleDefaultPaused.expected.status == "Paused" and
    .scenarios.disappearance.expectedAvailable == false and
    (.expectedActions | type == "array") and
    .forbiddenActionArg == "--player"' "$state_dir/policy.json" >/dev/null \
    || fail 'media policy fixture is incomplete or invalid'
  jq '.scenarios.onePlayer.state' "$state_dir/policy.json" >"$state_dir/player.json"

  real_jq=$(command -v jq)
  PATH="$state_dir/fixture-bin:$PATH" QS_TEST_STATE_DIR="$state_dir" QS_TEST_REAL_JQ="$real_jq" QT_QPA_PLATFORM=offscreen \
    "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
  qs_pid=$!
  register_fixture_qs "$qs_pid"
  wait_for_path "$state_dir/ready" 10 || fail 'media fixture did not become ready'
  wait_for_process "$qs_pid" 50 || rc=$?
  ((rc == 0)) || {
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail "media fixture exited unsuccessfully or timed out (rc=${rc})"
  }
  jq -e '.passed == true and .sharedIdentity == true and .policyPassed == true and
    .malformedPreserved == true and .disappearancePreserved == true and
    .recoveryPassed == true and .cadencePassed == true and
    .followCoalesced == true and .bareDefaultPassed == true and
    .noDuplicateEnablePassed == true and .followRestartPassed == true and
    .pendingInvalidationPassed == true and .queuedInvalidationPassed == true and
    .actionOrderPassed == true and .delayedActionPassed == true' \
    "$state_dir/result.json" >/dev/null || {
    jq . "$state_dir/result.json" >&2 || true
    sed -n '1,240p' "$state_dir/quickshell.log" >&2
    fail 'media fixture reported invalid state or action routing'
  }
  diff -u <(jq -r '.expectedActions[]' "$state_dir/policy.json") "$state_dir/actions.log" \
    || fail 'media fixture did not route exactly one expected action per gesture'
  ! rg -F -q -- "$(jq -r '.forbiddenActionArg' "$state_dir/policy.json")" "$state_dir/playerctl-calls.log" \
    || fail 'media actions invented an explicit player selector'
  [ ! -s "$state_dir/playerctl-overlap.log" ] \
    || fail 'media fixture observed overlapping snapshot or action commands'
  ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
    || fail 'media fixture logged a binding or construction error'
  [ ! -e "$state_dir/follow.active" ] || fail 'media follow active marker survived shell exit'
  for follow_record in "$state_dir"/processes/follow.*.record; do
    [ -e "$follow_record" ] || continue
    follow_pid=$(record_value pid "$follow_record")
    ! kill -0 "$follow_pid" 2>/dev/null || fail 'media follow process survived shell exit'
  done
  [ "$(rg -c '^start ' "$state_dir/playerctl-lifecycle.log")" -eq 2 ] \
    || fail 'media fixture did not perform exactly one forced follow restart'
  [ "$(rg -c '^term ' "$state_dir/playerctl-lifecycle.log")" -eq 2 ] \
    || fail 'media fixture did not clean both follow process generations'
  jq -c . "$state_dir/result.json"
}

run_cava_service_probe() {
  local mode state_dir qs_pid rc=0 record pid expected_config fixture_path tool
  printf 'quickshell-services: run_cava_service_probe\n'
  for mode in normal destruction failed-start failed-start-cancel failed-start-destruction; do
    state_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-cava-service.XXXXXX")
    fixture_state_dirs+=("$state_dir")
    mkdir -p "$state_dir/fixture-bin" "$state_dir/config/services/internal" "$state_dir/processes"
    ln -s "$audio_fixture_bin/cava" "$state_dir/fixture-bin/cava"
    fixture_path="$state_dir/fixture-bin:$PATH"
    if [[ "$mode" == failed-start* ]]; then
      for tool in bash cat date mkdir rmdir sleep; do
        ln -s "$(command -v "$tool")" "$state_dir/fixture-bin/$tool"
      done
      fixture_path="$state_dir/fixture-bin"
    fi
    cp "$cava_fixture_qml/shell.qml" "$state_dir/config/shell.qml"
    cp "$repo_root/home/configs/quickshell/cava-bar.conf" "$state_dir/config/cava-bar.conf"
    cp "$repo_root/home/configs/quickshell/services/CavaService.qml" "$state_dir/config/services/CavaService.qml"
    cp "$repo_root/home/configs/quickshell/services/internal/CavaParser.js" "$state_dir/config/services/internal/CavaParser.js"
    mkfifo "$state_dir/cava.fifo"
    : >"$state_dir/cava-lifecycle.log"
    expected_config="$state_dir/config/cava-bar.conf"

    PATH="$fixture_path" QS_TEST_STATE_DIR="$state_dir" \
      QS_TEST_EXPECTED_CONFIG="$expected_config" QS_TEST_MODE="$mode" QT_QPA_PLATFORM=offscreen \
      "$quickshell_bin" --no-color -p "$state_dir/config" >"$state_dir/quickshell.log" 2>&1 &
    qs_pid=$!
    register_fixture_qs "$qs_pid"

    if [ "$mode" = normal ]; then
      wait_for_process "$qs_pid" 20 || rc=$?
      ((rc == 0)) || {
        sed -n '1,240p' "$state_dir/quickshell.log" >&2
        fail "cava fixture exited unsuccessfully or timed out (rc=${rc})"
      }
      jq -e '.passed == true and .initialDemandPassed == true and
        .parsingPassed == true and .retryPassed == true and
        .recoveryPassed == true and .stopPassed == true and
        .restartPassed == true and .rapidDemandPassed == true and
        .canceledDemandPassed == true and .starts == 7' "$state_dir/result.json" >/dev/null \
        || fail 'cava fixture reported invalid parsing, demand, retry, or cleanup behavior'
    elif [ "$mode" = destruction ]; then
      wait_for_path "$state_dir/ready" 10 || fail 'cava destruction fixture did not become ready'
      kill -TERM "$qs_pid"
      wait_for_process "$qs_pid" 5 || true
    elif [ "$mode" = failed-start-destruction ]; then
      wait_for_path "$state_dir/ready" 10 || fail 'cava failed-start destruction fixture did not become ready'
      kill -TERM "$qs_pid"
      wait_for_process "$qs_pid" 5 || true
      ln -s "$(command -v setpriv)" "$state_dir/fixture-bin/setpriv"
      sleep 0.4
      [ ! -s "$state_dir/cava-lifecycle.log" ] \
        || fail 'cava retry survived shell destruction after FailedToStart'
    elif [ "$mode" = failed-start ]; then
      wait_for_path "$state_dir/ready" 10 || fail 'cava failed-start fixture did not request executable restoration'
      ln -s "$(command -v setpriv)" "$state_dir/fixture-bin/setpriv"
      wait_for_process "$qs_pid" 20 || rc=$?
      ((rc == 0)) || fail "cava failed-start fixture exited unsuccessfully or timed out (rc=${rc})"
      jq -e '.passed == true and .failedStartRecoveryPassed == true and .starts == 1' \
        "$state_dir/result.json" >/dev/null \
        || fail 'cava failed-start fixture did not recover through exactly one bounded retry'
    else
      wait_for_process "$qs_pid" 20 || rc=$?
      ((rc == 0)) || fail "cava failed-start cancellation fixture exited unsuccessfully or timed out (rc=${rc})"
      jq -e '.passed == true and .failedStartCancelPassed == true and .starts == 0' \
        "$state_dir/result.json" >/dev/null \
        || fail 'cava demand drop did not cancel failed-start retries'
    fi

    ! rg -n 'TypeError|ReferenceError|Failed to load configuration|ERROR:' "$state_dir/quickshell.log" \
      || fail 'cava fixture logged a binding or construction error'
    [ ! -s "$state_dir/cava-overlap.log" ] \
      || fail 'cava fixture observed overlapping instances'
    [ ! -d "$state_dir/cava.active" ] \
      || fail 'cava active marker survived fixture exit'
    for record in "$state_dir"/processes/cava.*.record; do
      [ -e "$record" ] || continue
      pid=$(record_value pid "$record")
      ! kill -0 "$pid" 2>/dev/null || fail 'cava process survived fixture exit'
    done
  done
}
