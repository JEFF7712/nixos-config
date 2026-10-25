#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_qml="${repo_root}/tests/quickshell/integration/process-cleanup"
fixture_bin="${repo_root}/tests/quickshell/fixtures/bin/qs-test-owned-process"
audio_native_fixture_qml="${repo_root}/tests/quickshell/integration/audio-native"
media_fixture_qml="${repo_root}/tests/quickshell/integration/media-service"
cava_fixture_qml="${repo_root}/tests/quickshell/integration/cava-service"
power_fixture_qml="${repo_root}/tests/quickshell/integration/power-service"
power_native_fixture_qml="${repo_root}/tests/quickshell/integration/power-native"
system_fixture_qml="${repo_root}/tests/quickshell/integration/system-service"
niri_fixture_qml="${repo_root}/tests/quickshell/integration/niri-service"
network_fixture_qml="${repo_root}/tests/quickshell/integration/network-service"
network_native_fixture_qml="${repo_root}/tests/quickshell/integration/network-native"
bluetooth_fixture_qml="${repo_root}/tests/quickshell/integration/bluetooth-service"
bluetooth_native_fixture_qml="${repo_root}/tests/quickshell/integration/bluetooth-native"
popup_only_fixture_qml="${repo_root}/tests/quickshell/integration/popup-only"
audio_fixture_bin="${repo_root}/tests/quickshell/fixtures/bin"
quickshell_bin=$(command -v quickshell || true)
declare -a fixture_state_dirs=()
declare -a fixture_qs_pids=()
declare -A fixture_qs_known=()
declare -A fixture_qs_reaped=()
declare -A fixture_qs_start=()
declare -A fixture_qs_signature=()
fixture_state=

for part in "${repo_root}/checks/quickshell-services"/*.bash; do
  # shellcheck source=/dev/null
  source "$part"
done
