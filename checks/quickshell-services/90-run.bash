# shellcheck shell=bash
# Sourced by checks/quickshell-services.bash; shares its globals.
if [ "${QS_TEST_FORCE_FAILURE_CHILD:-0}" = 1 ]; then
  run_forced_failure_child "${QS_TEST_PROBE_STATE_DIR:?QS_TEST_PROBE_STATE_DIR is required}"
fi

if [ "${QS_TEST_OVERLAP_TIMEOUT_PROBE_CHILD:-0}" = 1 ]; then
  run_overlap_descendant_probe
  exit 0
fi

if [ "${QS_TEST_TRANSIENT_TIMEOUT_PROBE_CHILD:-0}" = 1 ]; then
  run_transient_descendant_probe
  exit 0
fi

assert_native_probe_has_no_wpctl_dependency
assert_native_fixture_always_validates_public_contract
assert_variant_topbar_bindings_are_root_qualified

run_unit_tests
run_process_cleanup_fixture
run_native_construction_probes
run_media_service_probe
run_cava_service_probe
run_power_service_probe
run_brightness_service_probe
run_power_destruction_probe probe
run_power_destruction_probe action
run_power_native_construction_probe
run_system_service_probe
run_niri_service_probe
run_network_native_construction_probe
run_bluetooth_native_construction_probe
run_popup_only_composition_probe
assert_no_view_processes_for_migrated_domains
