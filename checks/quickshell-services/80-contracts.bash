# shellcheck shell=bash
# Sourced by checks/quickshell-services.bash; shares its globals.
assert_native_probe_has_no_wpctl_dependency() {
  local probe_body
  printf 'quickshell-services: assert_native_probe_has_no_wpctl_dependency\n'
  probe_body=$(sed -n '/^run_native_construction_probes() {$/,/^}$/p' "${repo_root}/checks/quickshell-services/20-core-fixtures.bash")
  ! rg -n 'command -v wpctl|wpctl status' <<<"$probe_body" \
    || fail 'native audio construction probe still depends on wpctl availability'
}

assert_native_fixture_always_validates_public_contract() {
  printf 'quickshell-services: assert_native_fixture_always_validates_public_contract\n'
  rg -q 'passed:[[:space:]]*validTypes && validRange' "$audio_native_fixture_qml/shell.qml" \
    || fail 'native audio fixture lets skipped backends bypass public contract validation'
  rg -q 'passed:[[:space:]]*validTypes && validRange' "$power_native_fixture_qml/shell.qml" \
    || fail 'native power fixture lets skipped backends bypass public contract validation'
  rg -q 'passed:[[:space:]]*validTypes && validRange' "$network_native_fixture_qml/shell.qml" \
    || fail 'native network fixture lets skipped backends bypass public contract validation'
  rg -q 'passed:[[:space:]]*validTypes && validRange' "$bluetooth_native_fixture_qml/shell.qml" \
    || fail 'native bluetooth fixture lets skipped backends bypass public contract validation'
}

assert_no_view_processes_for_migrated_domains() {
  local process_matches timer_matches domain_command_matches fixture_process_matches
  local process_count timer_count domain_command_count fixture_process_count
  local process_digest timer_digest domain_command_digest fixture_process_digest
  printf 'quickshell-services: assert_no_view_processes_for_migrated_domains\n'
  process_matches=$(rg --no-filename -g '*.qml' '(^|[[:space:]])Process[[:space:]]*\{' "$repo_root"/home/configs/quickshell* || true)
  timer_matches=$(rg --no-filename -g '*.qml' '(^|[[:space:]])Timer[[:space:]]*\{' "$repo_root"/home/configs/quickshell* || true)
  domain_command_matches=$(rg --no-filename -i -g '*.qml' 'wpctl|nmcli|bluetoothctl|upower|brightnessctl' "$repo_root"/home/configs/quickshell* || true)
  fixture_process_matches=$(rg --no-filename -g '*.qml' '(^|[[:space:]])Process[[:space:]]*\{' "$repo_root/tests/quickshell" || true)
  process_count=$(printf '%s\n' "$process_matches" | sed '/^$/d' | wc -l)
  timer_count=$(printf '%s\n' "$timer_matches" | sed '/^$/d' | wc -l)
  domain_command_count=$(printf '%s\n' "$domain_command_matches" | sed '/^$/d' | wc -l)
  fixture_process_count=$(printf '%s\n' "$fixture_process_matches" | sed '/^$/d' | wc -l)
  process_digest=$(printf '%s\n' "$process_matches" | sort | sha256sum | awk '{ print $1 }')
  timer_digest=$(printf '%s\n' "$timer_matches" | sort | sha256sum | awk '{ print $1 }')
  domain_command_digest=$(printf '%s\n' "$domain_command_matches" | sort | sha256sum | awk '{ print $1 }')
  fixture_process_digest=$(printf '%s\n' "$fixture_process_matches" | sort | sha256sum | awk '{ print $1 }')
  printf 'quickshell-services: production baseline Process=%s:%s Timer=%s:%s domain-command=%s:%s\n' \
    "$process_count" "$process_digest" "$timer_count" "$timer_digest" \
    "$domain_command_count" "$domain_command_digest"
  printf 'quickshell-services: fixture baseline Process=%s:%s (excluded from production)\n' \
    "$fixture_process_count" "$fixture_process_digest"
  local production_dir="$repo_root/home/configs/quickshell"
  local shell="$production_dir/shell.qml"
  local audio_service="$production_dir/services/AudioService.qml"
  local audio_backend="$production_dir/services/internal/PipewireAudioBackend.qml"
  local media_service="$production_dir/services/MediaService.qml"
  local media_model="$production_dir/services/internal/MediaModel.qml"
  local media_popup="$production_dir/MediaPopup.qml"
  local cava_service="$production_dir/services/CavaService.qml"
  local power_service="$production_dir/services/PowerService.qml"
  local power_model="$production_dir/services/internal/PowerModel.qml"
  local power_backend="$production_dir/services/internal/UPowerBackend.qml"
  local view

  rg -q '^import Quickshell\.Services\.Pipewire$' "$audio_backend" \
    || fail 'PipewireAudioBackend.qml must import Quickshell.Services.Pipewire'
  rg -q 'PwObjectTracker[[:space:]]*\{' "$audio_backend" \
    || fail 'PipewireAudioBackend.qml must instantiate PwObjectTracker'
  rg -q 'Internal\.PipewireAudioBackend[[:space:]]*\{' "$audio_service" \
    || fail 'AudioService.qml must compose the native backend'
  rg -q 'Internal\.AudioModel[[:space:]]*\{' "$audio_service" \
    || fail 'AudioService.qml must compose the backend-free model'
  ! rg -n 'Quickshell\.Services\.Pipewire|PwObjectTracker|property[^:]*\b(sink|sinkAudio|backend|current[A-Z][A-Za-z]*)\b' "$audio_service" \
    || fail 'AudioService.qml exposes native objects or writable model state'
  ! rg -n -i '(^|[[:space:]])Process[[:space:]]*\{|wpctl|pw-mon|commandQueue|enqueueCommand|probeDebounce|(^|[[:space:]])Timer[[:space:]]*\{' "$audio_service" \
    || fail 'AudioService.qml still contains the command-backed audio backend'

  for view in Topbar.qml VolumePopup.qml MediaPopup.qml; do
    ! rg -n -i 'wpctl|pw-mon' "$production_dir/$view" \
      || fail "$view still owns system-sink audio commands"
  done
  ! rg -n -i -g '*.qml' -g '!AudioService.qml' 'wpctl|pw-mon|pavucontrol' "$production_dir" \
    || fail 'system-sink audio command construction exists outside AudioService.qml'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{' "$production_dir/VolumePopup.qml" \
    || fail 'VolumePopup.qml still owns a Process'
  [ "$(rg -o 'Services\.AudioService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one Services.AudioService'
  rg -q 'id:[[:space:]]*audioService' "$shell" \
    || fail 'production shell.qml must name the AudioService audioService'
  rg -U -q 'Topbar[[:space:]]*\{[^}]*audioService:[[:space:]]*root\.sharedAudioService' "$shell" \
    || fail 'production shell.qml does not wire root audioService directly to Topbar'
  rg -U -q 'VolumePopup[[:space:]]*\{[^}]*audioService:[[:space:]]*audioService' "$shell" \
    || fail 'production shell.qml does not wire audioService directly to VolumePopup'
  rg -U -q 'Services\.MediaService[[:space:]]*\{[^}]*audioService:[[:space:]]*audioService' "$shell" \
    || fail 'production shell.qml does not wire AudioService directly to MediaService'
  ! rg -n 'topbar\.(volume|setVolume|adjustVolume|toggleMute|openMixer|run\([^\n]*(wpctl|pavucontrol))' \
    "$production_dir/VolumePopup.qml" "$production_dir/MediaPopup.qml" "$shell" \
    || fail 'migrated popups still route audio through topbar'

  [ -f "$media_service" ] || fail 'MediaService.qml is missing'
  [ -f "$media_model" ] || fail 'MediaModel.qml is missing'
  rg -q 'Internal\.MediaModel[[:space:]]*\{' "$media_service" \
    || fail 'MediaService.qml must compose the deep internal MediaModel'
  ! rg -n '(^|[[:space:]])(Process|Timer)[[:space:]]*\{|property[^:]*[[:space:]]_[A-Za-z]|_requestSnapshot|_applySnapshot|_enqueue|_startNext|_action|playerctl|refreshDebounce' "$media_service" \
    || fail 'MediaService.qml leaks mutable media ownership instead of remaining a thin facade'
  ! rg -U -q 'function _action\([^}]*refreshDebounce\.restart\(' "$media_model" \
    || fail 'MediaModel actions must schedule reconciliation after completion, not enqueue time'
  ! rg -U -q 'job && job\.reconcileAfter[^}]*_requestSnapshot\(' "$media_model" \
    || fail 'MediaModel action completion must reconcile through the debounce policy'
  [ "$(rg '^[[:space:]]*(required[[:space:]]+)?property' "$media_service" | rg -v 'readonly property' | sed 's/^[[:space:]]*//' | sort)" = $'property bool detailedMonitoring: false\nrequired property AudioService audioService' ] \
    || fail 'MediaService.qml exposes writable properties beyond audioService and detailedMonitoring'
  for public_property in available playing status title artist album artUrl positionSeconds lengthSeconds effectiveVolume shuffleEnabled volumeIsPlayer loopMode canSeek canTogglePlaying canGoNext canGoPrevious canShuffle canLoop canSetPlayerVolume; do
    rg -q "readonly property [^:]* ${public_property}:" "$media_service" \
      || fail "MediaService.qml is missing readonly public property: $public_property"
  done
  [ "$(rg -o 'Services\.MediaService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one Services.MediaService'
  ! rg -n -i -g '*.qml' -g '!MediaService.qml' -g '!MediaModel.qml' 'playerctl' "$production_dir" \
    || fail 'playerctl media commands exist outside the MediaService implementation'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io' "$media_popup" \
    || fail 'MediaPopup.qml still owns media processes, timers, or Quickshell.Io'
  ! rg -n 'media(Status|Title|Artist|Album|ArtUrl)|mediaFollowProc' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml still owns media scalar state or follow process'
  rg -q 'required property Services\.MediaService mediaService' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must require MediaService'
  rg -q 'required property Services\.MediaService mediaService' "$media_popup" \
    || fail 'MediaPopup.qml must require MediaService'
  for signature in \
    'function togglePlaying(): void' \
    'function next(): void' \
    'function previous(): void' \
    'function seek(seconds: real): void' \
    'function toggleShuffle(): void' \
    'function cycleLoop(): void' \
    'function setEffectiveVolume(value: real): void'; do
    rg -F -q "$signature" "$media_service" \
      || fail "MediaService.qml is missing typed action signature: $signature"
  done
  ! rg -U -q 'onDetailedMonitoringChanged:[^\n]*refreshDebounce|onDetailedMonitoringChanged:[[:space:]]*\{[^}]*refreshDebounce' "$media_service" \
    || fail 'MediaService detailedMonitoring enable must not schedule the follow debounce timer'
  # playerctl --follow only reprints when the formatted string changes; status-only
  # misses track swaps while Playing (popup/bar stay stale until a click reconciles).
  rg -F -q '"{{status}}\t{{title}}\t{{artist}}\t{{album}}\t{{mpris:artUrl}}\t{{mpris:length}}\t{{shuffle}}\t{{loop}}"' "$media_model" \
    || fail 'MediaModel follow format must include track fields, not status alone'
  rg -U -q 'Topbar[[:space:]]*\{[^}]*mediaService:[[:space:]]*root\.sharedMediaService' "$shell" \
    || fail 'production shell.qml does not wire MediaService directly to Topbar'
  rg -U -q 'MediaPopup[[:space:]]*\{[^}]*mediaService:[[:space:]]*mediaService' "$shell" \
    || fail 'production shell.qml does not wire MediaService directly to MediaPopup'
  ! rg -n 'status:[[:space:]]*topbar\.media|track:[[:space:]]*topbar\.media|artist:[[:space:]]*topbar\.media|album:[[:space:]]*topbar\.media|artUrl:[[:space:]]*topbar\.media' "$shell" \
    || fail 'MediaPopup still receives media state through Topbar'

  [ -f "$cava_service" ] || fail 'CavaService.qml is missing'
  [ "$(rg '^[[:space:]]*property' "$cava_service" | rg -v 'readonly property|property[^:]* _' | sed 's/^[[:space:]]*//' | sort)" = $'property bool playing: false\nproperty bool requested: false' ] \
    || fail 'CavaService.qml public demand contract or private state changed unexpectedly'
  rg -q 'readonly property list<int> values:' "$cava_service" \
    || fail 'CavaService.qml must expose typed readonly values'
  if ! rg -q '^bars = 12$' "$production_dir/cava-bar.conf" \
    || ! rg -q '^var barCount = 12;$' "$production_dir/services/internal/CavaParser.js"; then
    fail 'Cava parser width must match cava-bar.conf'
  fi
  rg -U -q 'command:[[:space:]]*\["setpriv",[[:space:]]*"--pdeathsig",[[:space:]]*"TERM",[[:space:]]*"--",[[:space:]]*"cava",[[:space:]]*"-p",[[:space:]]*root\._configPath\]' "$cava_service" \
    || fail 'CavaService.qml must own the parent-death-protected Cava command'
  [ "$(rg -o 'Services\.CavaService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one CavaService'
  rg -U -q 'Services\.CavaService[[:space:]]*\{[^}]*playing:[[:space:]]*mediaService\.playing[^}]*requested:[[:space:]]*root\.anyBarCavaRequested[[:space:]]*\|\|[[:space:]]*mediaPopup\.active' "$shell" \
    || fail 'production shell.qml must bind exact media, multi-bar, and popup Cava demand'
  rg -q 'required property Services\.CavaService cavaService' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must require CavaService'
  rg -q 'readonly property bool cavaRequested:[[:space:]]*mediaPill\.visible' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml Cava demand must exactly follow mediaPill.visible'
  rg -q 'required property Services\.CavaService cavaService' "$media_popup" \
    || fail 'MediaPopup.qml must require CavaService'
  ! rg -n 'cavaConfigPath|cavaProc|property var cavaValues|setpriv[^\n]*cava|command:[^\n]*cava' \
    "$production_dir/Topbar.qml" "$media_popup" \
    || fail 'Cava process, parsing, or writable values remain in presentation files'
  rg -q 'model:[[:space:]]*topbarWindow\.cavaService\.values' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must render CavaService values directly'
  rg -q 'root\.cavaService\.values' "$media_popup" \
    || fail 'MediaPopup.qml must render CavaService values directly'

  [ -f "$power_service" ] || fail 'PowerService.qml is missing'
  [ -f "$power_model" ] || fail 'PowerModel.qml is missing'
  [ -f "$power_backend" ] || fail 'UPowerBackend.qml is missing'
  rg -q '^import Quickshell\.Services\.UPower$' "$power_backend" \
    || fail 'UPowerBackend.qml must import Quickshell.Services.UPower'
  rg -q 'UPower\.displayDevice' "$power_backend" \
    || fail 'UPowerBackend.qml must read UPower.displayDevice'
  rg -q 'PowerProfiles\.profile' "$power_backend" \
    || fail 'UPowerBackend.qml must read or write PowerProfiles.profile'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io' "$power_backend" \
    || fail 'UPowerBackend.qml must stay a pure native reader/writer with no subprocess ownership'
  rg -q 'Internal\.UPowerBackend[[:space:]]*\{' "$power_service" \
    || fail 'PowerService.qml must compose the native UPower/PowerProfiles backend'
  rg -q 'Internal\.PowerModel[[:space:]]*\{' "$power_service" \
    || fail 'PowerService.qml must compose the deep internal PowerModel'
  rg -U -q 'Internal\.PowerModel[[:space:]]*\{[^}]*backend:[[:space:]]*backend' "$power_service" \
    || fail 'PowerService.qml must wire the native backend directly into PowerModel'
  [ "$(rg '^[[:space:]]*property' "$power_service" | rg -v 'readonly property' | sed 's/^[[:space:]]*//' | sort)" = 'property bool detailedMonitoring: false' ] \
    || fail 'PowerService.qml must expose only the narrow detailed-monitoring demand input'
  ! rg -n 'Quickshell\.Services\.UPower|PowerProfiles|property[^:]*\b(device|backend)\b' "$power_service" \
    || fail 'PowerService.qml exposes native power objects or writable backend state'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|"upower"|"powerprofilesctl"' "$power_service" \
    || fail 'PowerService.qml still contains subprocess-backed power adapters'
  ! rg -n 'Quickshell\.Services\.UPower' "$power_model" \
    || fail 'PowerModel.qml must not import native UPower services directly; use the backend'
  ! rg -n -g '*.qml' '"upower"|"powerprofilesctl"' "$production_dir" \
    || fail 'upower/powerprofilesctl command literals remain in production Quickshell QML'
  [ "$(rg -o 'Services\.PowerService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one PowerService'
  for view in Topbar.qml BatteryPopup.qml; do
    rg -q 'required property Services\.PowerService powerService' "$production_dir/$view" \
      || fail "$view must require PowerService"
  done
  rg -U -q 'Topbar[[:space:]]*\{[^}]*powerService:[[:space:]]*root\.sharedPowerService' "$shell" \
    || fail 'production shell.qml does not wire PowerService directly to Topbar'
  rg -U -q 'BatteryPopup[[:space:]]*\{[^}]*powerService:[[:space:]]*powerService' "$shell" \
    || fail 'production shell.qml does not wire PowerService directly to BatteryPopup'
  rg -U -q 'Services\.PowerService[[:space:]]*\{[^}]*detailedMonitoring:[[:space:]]*batteryPopup\.active[[:space:]]*\|\|[[:space:]]*batteryPopup\.warming' "$shell" \
    || fail 'production shell.qml must bind power cadence demand to BatteryPopup active and warming state'
  rg -q 'interval:[[:space:]]*root\.detailedMonitoring \? 5000 : 30000' "$power_model" \
    || fail 'PowerModel cadence must be five seconds shown and thirty seconds hidden'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|upower|powerprofilesctl|charge_control_end_threshold|stasis' \
    "$production_dir/BatteryPopup.qml" \
    || fail 'BatteryPopup.qml still owns power processes, timers, imports, or command construction'
  ! rg -n 'batteryPercent|powerProfileOrder|property string powerProfile|setPowerProfile|powerprofilesctl|/sys/class/power_supply/BAT' \
    "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml still owns power state, parsing, or command construction'
  rg -U -q 'function batteryIcon\(\)[^{]*\{[^}]*if \(!topbarWindow\.powerService\.available\)[[:space:]]*return "󰁹"' \
    "$production_dir/Topbar.qml" \
    || fail 'Topbar unavailable battery icon no longer preserves the previous full/default visual'
  rg -q 'powerService\.state === "full" \? "fully charged"' "$production_dir/BatteryPopup.qml" \
    || fail 'BatteryPopup full state no longer renders as fully charged'
  for signature in \
    'function setProfile(profile: string): void' \
    'function cycleProfile(direction: int): void' \
    'function setChargeLimit(percent: int): void' \
    'function toggleChargeLimit(): void' \
    'function toggleIdleInhibit(): void'; do
    rg -F -q "$signature" "$power_service" \
      || fail "PowerService.qml is missing typed action signature: $signature"
  done

  local system_service="$production_dir/services/SystemService.qml"
  local system_model="$production_dir/services/internal/SystemModel.qml"
  local system_popup="$production_dir/SystemPopup.qml"
  [ -f "$system_service" ] || fail 'SystemService.qml is missing'
  [ -f "$system_model" ] || fail 'SystemModel.qml is missing'
  rg -q 'Internal\.SystemModel[[:space:]]*\{' "$system_service" \
    || fail 'SystemService.qml must compose the deep internal SystemModel'
  [ "$(rg '^[[:space:]]*property' "$system_service" | rg -v 'readonly property' | sed 's/^[[:space:]]*//' | sort)" = 'property bool detailedMonitoring: false' ] \
    || fail 'SystemService.qml must expose only the narrow detailed-monitoring demand input'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"lock-screen"|"systemctl"' "$system_service" \
    || fail 'SystemService.qml must stay a thin facade with no owned processes or command literals'
  for public_property in available cpuPercent ramUsedGiB ramPercent diskPercent hostName kernel uptime nixGeneration lastError; do
    rg -q "readonly property [^:]* ${public_property}:" "$system_service" \
      || fail "SystemService.qml is missing readonly public property: $public_property"
  done
  for signature in \
    'function lock(): void' \
    'function suspend(): void' \
    'function reboot(): void' \
    'function powerOff(): void'; do
    rg -F -q "$signature" "$system_service" \
      || fail "SystemService.qml is missing typed action signature: $signature"
  done
  rg -U -q 'execDetached\(\["lock-screen"\]\)' "$system_model" \
    || fail 'SystemModel.qml must own the exact lock-screen argv'
  rg -U -q 'execDetached\(\["systemctl",[[:space:]]*"suspend"\]\)' "$system_model" \
    || fail 'SystemModel.qml must own the exact systemctl suspend argv'
  rg -U -q 'execDetached\(\["systemctl",[[:space:]]*"reboot"\]\)' "$system_model" \
    || fail 'SystemModel.qml must own the exact systemctl reboot argv'
  rg -U -q 'execDetached\(\["systemctl",[[:space:]]*"poweroff"\]\)' "$system_model" \
    || fail 'SystemModel.qml must own the exact systemctl poweroff argv'
  ! rg -n -i -g '*.qml' -g '!SystemModel.qml' 'lock-screen|"systemctl"' "$production_dir" \
    || fail 'lock-screen/systemctl command construction exists outside SystemModel.qml'
  [ "$(rg -o 'Services\.SystemService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one Services.SystemService'
  rg -q 'id:[[:space:]]*systemService' "$shell" \
    || fail 'production shell.qml must name the SystemService systemService'
  rg -U -q 'Topbar[[:space:]]*\{[^}]*systemService:[[:space:]]*root\.sharedSystemService' "$shell" \
    || fail 'production shell.qml does not wire root systemService directly to Topbar'
  rg -U -q 'SystemPopup[[:space:]]*\{[^}]*systemService:[[:space:]]*systemService' "$shell" \
    || fail 'production shell.qml does not wire systemService directly to SystemPopup'
  rg -U -q 'Services\.SystemService[[:space:]]*\{[^}]*detailedMonitoring:[[:space:]]*systemPopup\.active[[:space:]]*\|\|[[:space:]]*systemPopup\.warming' "$shell" \
    || fail 'production shell.qml must bind system metadata cadence demand to SystemPopup active and warming state'
  rg -q 'required property Services\.SystemService systemService' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must require SystemService'
  rg -q 'required property Services\.SystemService systemService' "$system_popup" \
    || fail 'SystemPopup.qml must require SystemService'
  ! rg -n 'statsProc|cpuUsage|ramUsage|diskUsage' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml still owns cpu/ram/disk metrics state or the composite stats process'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io' "$system_popup" \
    || fail 'SystemPopup.qml still owns processes, timers, or Quickshell.Io'
  ! rg -n '/proc/stat|/proc/meminfo|"df"|df -P|hostnamectl|uname -r|readlink[^\n]*nix' "$system_popup" \
    || fail 'SystemPopup.qml still constructs system-metrics or metadata commands'
  ! rg -n '"niri"|niri msg' "$system_popup" \
    || fail 'SystemPopup.qml must not contain any niri command construction; logout is a NiriService action'
  ! rg -n 'niri msg action quit -s' "$system_service" "$system_model" \
    || fail 'Niri session logout must remain a NiriService action, not SystemService'
  ! rg -n 'sleep 0\.2|MARK_CPU2|MARK_DISK' "$production_dir/services/internal/SystemParser.js" \
    || fail 'System metrics must sample CPU once per polling interval without an inline sleep'
  rg -q 'var DISK_COMMAND = "df -P / 2>&1"' "$production_dir/services/internal/SystemParser.js" \
    || fail 'Disk usage must use a separate command'
  rg -U -q 'id:[[:space:]]*metricsTimer[^}]*interval:[[:space:]]*3000' "$system_model" \
    || fail 'CPU and memory polling cadence must remain three seconds'
  rg -U -q 'id:[[:space:]]*diskTimer[^}]*interval:[[:space:]]*60000' "$system_model" \
    || fail 'Disk polling must use the slower sixty-second cadence'
  rg -q 'computeCpuPercent\(next\.cpuUsedTotal, next\.cpuOverallTotal, cpuTotals\)' "$production_dir/services/internal/SystemParser.js" \
    || fail 'CPU usage must be calculated from consecutive polling samples'

  local niri_service="$production_dir/services/NiriService.qml"
  local niri_model="$production_dir/services/internal/NiriModel.qml"
  local niri_parser="$production_dir/services/internal/NiriParser.js"
  [ -f "$niri_service" ] || fail 'NiriService.qml is missing'
  [ -f "$niri_model" ] || fail 'NiriModel.qml is missing'
  [ -f "$niri_parser" ] || fail 'NiriParser.js is missing'
  rg -q 'Internal\.NiriModel[[:space:]]*\{' "$niri_service" \
    || fail 'NiriService.qml must compose the deep internal NiriModel'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"niri"' "$niri_service" \
    || fail 'NiriService.qml must stay a thin facade with no owned processes or command literals'
  for public_property in activeWorkspaceId workspaces focusedTitle focusedAppId streamHealthy lastError; do
    rg -q "readonly property [^:]* ${public_property}:" "$niri_service" \
      || fail "NiriService.qml is missing readonly public property: $public_property"
  done
  for signature in \
    'function focusWorkspace(output: string, id: int): void' \
    'function focusAdjacent(output: string, direction: int): void' \
    'function quitSession(): void'; do
    rg -F -q "$signature" "$niri_service" \
      || fail "NiriService.qml is missing typed action signature: $signature"
  done
  rg -U -q 'command:[[:space:]]*\["niri",[[:space:]]*"msg",[[:space:]]*"-j",[[:space:]]*"workspaces"\]' "$niri_model" \
    || fail 'NiriModel.qml must own the exact direct workspaces snapshot argv'
  rg -U -q 'command:[[:space:]]*\["niri",[[:space:]]*"msg",[[:space:]]*"-j",[[:space:]]*"focused-window"\]' "$niri_model" \
    || fail 'NiriModel.qml must own the exact direct focused-window snapshot argv'
  rg -U -q 'command:[[:space:]]*\["setpriv",[[:space:]]*"--pdeathsig",[[:space:]]*"TERM",[[:space:]]*"--",[[:space:]]*"niri",[[:space:]]*"msg",[[:space:]]*"-j",[[:space:]]*"event-stream"\]' "$niri_model" \
    || fail 'NiriModel.qml must own the exact parent-death-protected event-stream argv'
  rg -q '"focus-monitor"' "$niri_model" \
    || fail 'NiriModel.qml must focus the target monitor before workspace actions'
  rg -U -q 'execDetached\(\["niri",[[:space:]]*"msg",[[:space:]]*"action",[[:space:]]*"quit",[[:space:]]*"-s"\]\)' "$niri_model" \
    || fail 'NiriModel.qml must own the exact session quit argv'
  ! rg -n -i -g '*.qml' -g '!NiriModel.qml' -g '!NiriService.qml' '"niri"|niri msg' "$production_dir" \
    || fail 'niri command construction exists outside the NiriService implementation'
  [ "$(rg -o 'Services\.NiriService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one Services.NiriService'
  rg -q 'id:[[:space:]]*niriService' "$shell" \
    || fail 'production shell.qml must name the NiriService niriService'
  rg -U -q 'Topbar[[:space:]]*\{[^}]*niriService:[[:space:]]*root\.sharedNiriService' "$shell" \
    || fail 'production shell.qml does not wire root niriService directly to Topbar'
  rg -U -q 'SystemPopup[[:space:]]*\{[^}]*niriService:[[:space:]]*niriService' "$shell" \
    || fail 'production shell.qml does not wire niriService directly to SystemPopup'
  rg -q 'required property Services\.NiriService niriService' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must require NiriService'
  rg -q 'required property Services\.NiriService niriService' "$system_popup" \
    || fail 'SystemPopup.qml must require NiriService'
  ! rg -n 'workspacesProc|titleProc|niriEventStream|\bactiveWorkspace\b|occupiedWorkspaces|\bworkspaceList\b' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml still owns Niri processes, timers, parser state, or command construction'
  rg -q 'model:[[:space:]]*topbarWindow\.niriService\.workspaces' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must render NiriService workspaces directly'
  rg -q 'visible:[[:space:]]*model\.output[[:space:]]*===[[:space:]]*topbarWindow\.screen\.name' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must show only workspaces assigned to its screen'
  ! rg -n '\(topbarWindow\.activeWorkspace - 1\) \* 36' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml workspace indicator must not assume workspace id minus one'
  rg -F -q 'niriService.focusWorkspace(topbarWindow.screen.name,' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml workspace click must target its own screen'
  rg -F -q 'niriService.focusAdjacent(topbarWindow.screen.name,' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml workspace wheel must target its own screen'
  rg -q 'niriService\.quitSession\(\)' "$system_popup" \
    || fail 'SystemPopup.qml logout must call niriService.quitSession()'

  local network_service="$production_dir/services/NetworkService.qml"
  local network_backend="$production_dir/services/internal/NetworkBackend.qml"
  local network_model="$production_dir/services/internal/NetworkModel.qml"
  local network_parser="$production_dir/services/internal/NetworkParser.js"
  local network_reducer="$production_dir/services/internal/NetworkReducer.js"
  local wifi_popup="$production_dir/WifiPopup.qml"
  [ -f "$network_service" ] || fail 'NetworkService.qml is missing'
  [ -f "$network_backend" ] || fail 'NetworkBackend.qml is missing'
  [ -f "$network_model" ] || fail 'NetworkModel.qml is missing'
  [ -f "$network_parser" ] || fail 'NetworkParser.js is missing'
  [ -f "$network_reducer" ] || fail 'NetworkReducer.js is missing'
  rg -q '^import Quickshell\.Networking$' "$network_backend" \
    || fail 'NetworkBackend.qml must import Quickshell.Networking'
  rg -q 'Networking\.(backend|wifiEnabled|connectivity|devices)' "$network_backend" \
    || fail 'NetworkBackend.qml must read native Networking singleton state'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"nmcli"' "$network_backend" \
    || fail 'NetworkBackend.qml must not own processes, timers, or nmcli'
  rg -q 'Internal\.NetworkBackend[[:space:]]*\{' "$network_service" \
    || fail 'NetworkService.qml must compose the native NetworkBackend'
  rg -q 'Internal\.NetworkModel[[:space:]]*\{' "$network_service" \
    || fail 'NetworkService.qml must compose the deep internal NetworkModel'
  [ "$(rg '^[[:space:]]*property' "$network_service" | rg -v 'readonly property' | sed 's/^[[:space:]]*//' | sort)" = 'property bool scanningRequested: false' ] \
    || fail 'NetworkService.qml must expose only the narrow scanning-demand input'
  ! rg -n 'Quickshell\.Networking|property[^:]*\b(backend|wifiDevice|native)\b|(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"nmcli"' "$network_service" \
    || fail 'NetworkService.qml must stay a thin facade with no native objects, processes, or nmcli'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"nmcli"|Quickshell\.Networking' "$network_model" \
    || fail 'NetworkModel.qml must stay backend-free of Process/Timer/nmcli/Networking imports'
  for public_property in available wifiAvailable wifiEnabled wiredConnected connected activeSsid activeSignal activeSecurity wiredConnections networks; do
    rg -q "readonly property [^:]* ${public_property}:" "$network_service" \
      || fail "NetworkService.qml is missing readonly public property: $public_property"
  done
  for signature in \
    'function setWifiEnabled(enabled: bool): void' \
    'function connectWired(id: string): void' \
    'function connectKnown(ssid: string): void' \
    'function connectInteractive(ssid: string): void' \
    'function openSettings(): void'; do
    rg -F -q "$signature" "$network_service" \
      || fail "NetworkService.qml is missing typed action signature: $signature"
  done
  rg -q 'interactiveConnectArgv|settingsArgv' "$network_parser" \
    || fail 'NetworkParser.js must own the kitty interactive/settings argv helpers'
  ! rg -n -i -g '*.qml' -g '*.js' 'nmcli' "$production_dir" \
    || fail 'nmcli command construction remains in production Quickshell code'
  [ "$(rg -o 'Services\.NetworkService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one Services.NetworkService'
  rg -q 'id:[[:space:]]*networkService' "$shell" \
    || fail 'production shell.qml must name the NetworkService networkService'
  rg -U -q 'Services\.NetworkService[[:space:]]*\{[^}]*scanningRequested:[[:space:]]*wifiPopup\.active[[:space:]]*\|\|[[:space:]]*wifiPopup\.warming' "$shell" \
    || fail 'production shell.qml must bind scanningRequested to WifiPopup active and warming state'
  rg -U -q 'Topbar[[:space:]]*\{[^}]*networkService:[[:space:]]*root\.sharedNetworkService' "$shell" \
    || fail 'production shell.qml does not wire root networkService directly to Topbar'
  rg -U -q 'WifiPopup[[:space:]]*\{[^}]*networkService:[[:space:]]*networkService' "$shell" \
    || fail 'production shell.qml does not wire networkService directly to WifiPopup'
  rg -q 'required property Services\.NetworkService networkService' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must require NetworkService'
  rg -q 'required property Services\.NetworkService networkService' "$wifi_popup" \
    || fail 'WifiPopup.qml must require NetworkService'
  ! rg -n -i 'networkProc|nmcli|networkIcon:[[:space:]]*"' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml still owns network connectivity state, the residual nmcli probe, or nmcli command construction'
  ! rg -n -i '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|nmcli' "$wifi_popup" \
    || fail 'WifiPopup.qml still owns network processes, timers, or nmcli command construction'
  rg -q 'networkService\.openSettings\(\)' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml right-click settings must call networkService.openSettings()'
  rg -U -q 'function networkIcon\(\)[[:space:]]*\{[^}]*networkService\.wiredConnected[^}]*networkService\.activeSsid' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml network icon must prefer wired over Wi-Fi state'
  rg -q 'networkService\.setWifiEnabled\(' "$wifi_popup" \
    || fail 'WifiPopup.qml radio toggle must call networkService.setWifiEnabled'
  rg -q 'networkService\.connectWired\(' "$wifi_popup" \
    || fail 'WifiPopup.qml wired row must call networkService.connectWired'
  rg -q 'networkService\.connectKnown\(' "$wifi_popup" \
    || fail 'WifiPopup.qml known-network click must call networkService.connectKnown'
  rg -q 'networkService\.connectInteractive\(' "$wifi_popup" \
    || fail 'WifiPopup.qml unknown-network click must call networkService.connectInteractive'
  rg -q 'model:[[:space:]]*root\.networkService\.wifiEnabled[[:space:]]*\?[[:space:]]*root\.networkService\.networks' "$wifi_popup" \
    || fail 'WifiPopup.qml must render NetworkService networks directly'

  local bluetooth_service="$production_dir/services/BluetoothService.qml"
  local bluetooth_backend="$production_dir/services/internal/BluetoothBackend.qml"
  local bluetooth_model="$production_dir/services/internal/BluetoothModel.qml"
  local bluetooth_parser="$production_dir/services/internal/BluetoothParser.js"
  local bluetooth_reducer="$production_dir/services/internal/BluetoothReducer.js"
  local bluetooth_popup="$production_dir/BluetoothPopup.qml"
  [ -f "$bluetooth_service" ] || fail 'BluetoothService.qml is missing'
  [ -f "$bluetooth_backend" ] || fail 'BluetoothBackend.qml is missing'
  [ -f "$bluetooth_model" ] || fail 'BluetoothModel.qml is missing'
  [ -f "$bluetooth_parser" ] || fail 'BluetoothParser.js is missing'
  [ -f "$bluetooth_reducer" ] || fail 'BluetoothReducer.js is missing'
  rg -q '^import Quickshell\.Bluetooth$' "$bluetooth_backend" \
    || fail 'BluetoothBackend.qml must import Quickshell.Bluetooth'
  rg -q 'Bluetooth\.defaultAdapter' "$bluetooth_backend" \
    || fail 'BluetoothBackend.qml must read native Bluetooth.defaultAdapter'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"busctl"' "$bluetooth_backend" \
    || fail 'BluetoothBackend.qml must not own processes, timers, or busctl'
  rg -q 'Internal\.BluetoothBackend[[:space:]]*\{' "$bluetooth_service" \
    || fail 'BluetoothService.qml must compose the native BluetoothBackend'
  rg -q 'Internal\.BluetoothModel[[:space:]]*\{' "$bluetooth_service" \
    || fail 'BluetoothService.qml must compose the deep internal BluetoothModel'
  [ "$(rg '^[[:space:]]*property' "$bluetooth_service" | rg -v 'readonly property' | sed 's/^[[:space:]]*//' | sort)" = 'property bool detailedMonitoring: false' ] \
    || fail 'BluetoothService.qml must expose only the narrow detailed-monitoring demand input'
  ! rg -n 'Quickshell\.Bluetooth|property[^:]*\b(backend|native)\b|(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"busctl"' "$bluetooth_service" \
    || fail 'BluetoothService.qml must stay a thin facade with no native objects, processes, or busctl'
  ! rg -n '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|Quickshell\.Io|"busctl"|Quickshell\.Bluetooth' "$bluetooth_model" \
    || fail 'BluetoothModel.qml must stay backend-free of Process/Timer/busctl/Bluetooth imports'
  for public_property in available enabled connectedCount devices; do
    rg -q "readonly property [^:]* ${public_property}:" "$bluetooth_service" \
      || fail "BluetoothService.qml is missing readonly public property: $public_property"
  done
  for signature in \
    'function setEnabled(enabled: bool): void' \
    'function toggleDevice(id: string): void' \
    'function openManager(): void'; do
    rg -F -q "$signature" "$bluetooth_service" \
      || fail "BluetoothService.qml is missing typed action signature: $signature"
  done
  rg -q 'openManagerCommand' "$bluetooth_parser" \
    || fail 'BluetoothParser.js must own the blueman-manager launch argv'
  ! rg -n -i -g '*.qml' -g '*.js' -g '!BluetoothParser.js' 'busctl|blueman-manager' "$production_dir" \
    || fail 'bluetooth command construction exists outside BluetoothParser.js'
  [ "$(rg -o 'Services\.BluetoothService[[:space:]]*\{' "$shell" | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must instantiate exactly one Services.BluetoothService'
  rg -U -q 'Services\.BluetoothService[[:space:]]*\{[^}]*detailedMonitoring:[[:space:]]*bluetoothPopup\.active[[:space:]]*\|\|[[:space:]]*bluetoothPopup\.warming' "$shell" \
    || fail 'production shell.qml must bind bluetooth cadence demand to BluetoothPopup active and warming state'
  rg -U -q 'Topbar[[:space:]]*\{[^}]*bluetoothService:[[:space:]]*root\.sharedBluetoothService' "$shell" \
    || fail 'production shell.qml does not wire root bluetoothService directly to Topbar'
  rg -U -q 'BluetoothPopup[[:space:]]*\{[^}]*bluetoothService:[[:space:]]*bluetoothService' "$shell" \
    || fail 'production shell.qml does not wire bluetoothService directly to BluetoothPopup'
  rg -q 'required property Services\.BluetoothService bluetoothService' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml must require BluetoothService'
  rg -q 'required property Services\.BluetoothService bluetoothService' "$bluetooth_popup" \
    || fail 'BluetoothPopup.qml must require BluetoothService'
  ! rg -n -i '(^|[[:space:]])Process[[:space:]]*\{|(^|[[:space:]])Timer[[:space:]]*\{|busctl|blueman' "$bluetooth_popup" \
    || fail 'BluetoothPopup.qml still owns bluetooth processes, timers, or command construction'
  rg -q 'bluetoothService\.openManager\(\)' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml right-click manager must call bluetoothService.openManager()'
  rg -q 'bluetoothService\.setEnabled\(' "$bluetooth_popup" \
    || fail 'BluetoothPopup.qml adapter toggle must call bluetoothService.setEnabled'
  rg -q 'bluetoothService\.toggleDevice\(' "$bluetooth_popup" \
    || fail 'BluetoothPopup.qml device click must call bluetoothService.toggleDevice'

  # Final presentation-split invariants (Task 12).
  local migrated_view
  for migrated_view in Topbar.qml VolumePopup.qml WifiPopup.qml BluetoothPopup.qml BatteryPopup.qml SystemPopup.qml MediaPopup.qml; do
    ! rg -n '(^|[[:space:]])Process[[:space:]]*\{' "$production_dir/$migrated_view" \
      || fail "$migrated_view still owns a Process block"
    ! rg -n 'Quickshell\.execDetached|execDetached\(' "$production_dir/$migrated_view" \
      || fail "$migrated_view still constructs detached domain commands"
  done
  ! rg -n -i 'wpctl|nmcli|busctl|bluetoothctl|playerctl|upower' \
    "$production_dir/Topbar.qml" \
    "$production_dir/VolumePopup.qml" \
    "$production_dir/WifiPopup.qml" \
    "$production_dir/BluetoothPopup.qml" \
    "$production_dir/BatteryPopup.qml" \
    "$production_dir/SystemPopup.qml" \
    "$production_dir/MediaPopup.qml" \
    || fail 'migrated views still contain domain command literals'
  ! rg -n 'topbar\.' \
    "$production_dir"/VolumePopup.qml \
    "$production_dir"/WifiPopup.qml \
    "$production_dir"/BluetoothPopup.qml \
    "$production_dir"/BatteryPopup.qml \
    "$production_dir"/SystemPopup.qml \
    "$production_dir"/MediaPopup.qml \
    "$production_dir"/NotificationsPopup.qml \
    "$production_dir"/CalendarPopup.qml \
    "$production_dir"/services/*.qml \
    "$production_dir"/services/internal/*.qml \
    || fail 'popups or services still reference the topbar id'
  topbar_type_refs=$(rg -n '\bTopbar\b' "$shell" || true)
  [ "$(printf '%s\n' "$topbar_type_refs" | sed '/^$/d' | wc -l)" -eq 1 ] \
    || fail 'production shell.qml must reference the Topbar type only in its presentation instantiation'
  rg -U -q 'Variants[[:space:]]*\{[^}]*id:[[:space:]]*barVariants[^}]*model:[[:space:]]*Quickshell\.screens' "$shell" \
    || fail 'production shell.qml must create a Topbar variant for every connected screen'
  rg -U -q 'Topbar[[:space:]]*\{[^}]*property var modelData[^}]*screen:[[:space:]]*modelData' "$shell" \
    || fail 'each Topbar variant must bind its window to its model screen'
  rg -q 'root\.showOnly\([^,]+,[^,]+,[[:space:]]*modelData\)' "$shell" \
    || fail 'Topbar popups must open on the screen of the clicked bar'
  rg -q 'notificationCount:[[:space:]]*NotifService\.count' "$shell" \
    || fail 'production shell.qml must bind Topbar notificationCount from NotifService.count'
  ! rg -n 'notificationsPopup\.unreadCount' "$shell" \
    || fail 'production shell.qml still routes notification count through NotificationsPopup'
  ! rg -n 'function[[:space:]]+run\(' "$production_dir/Topbar.qml" \
    || fail 'Topbar.qml still exposes the obsolete run() helper'
  ! rg -n -i 'statsProc|statsTimer|volumeProbe|volumeDebounce|volumeSubscribeProc' \
    "$production_dir/Topbar.qml" "$shell" \
    || fail 'old composite stats command residue remains in Topbar or shell'
  rg -q 'property bool shown: false' "$production_dir/InfoPopup.qml" \
    || fail 'InfoPopup.qml must keep the shown lifecycle property'
  rg -q 'readonly property bool active:' "$production_dir/InfoPopup.qml" \
    || fail 'InfoPopup.qml must keep the active lifecycle property'
  rg -q 'readonly property bool mapped:' "$production_dir/InfoPopup.qml" \
    || fail 'InfoPopup.qml must keep the mapped lifecycle property'
  rg -q 'property bool warming: false' "$production_dir/InfoPopup.qml" \
    || fail 'InfoPopup.qml must keep the warming lifecycle property'
  rg -q 'property bool ready: false' "$production_dir/InfoPopup.qml" \
    || fail 'InfoPopup.qml must keep the startup ready gate'
  rg -q 'function lockPose()' "$production_dir/InfoPopup.qml" \
    || fail 'InfoPopup.qml must lock pose before warm height mutations'
  rg -q 'if \(root\.warming\)' "$production_dir/InfoPopup.qml" \
    || fail 'InfoPopup.qml must force opacity 0 while warming (hover flash guard)'
  ! rg -q 'function warmHeight()' "$production_dir/InfoPopup.qml" \
    || fail 'InfoPopup.qml must not use full-height attached warmHeight (hover flash)'
  # Documented presentation timers: clock tick in Topbar, InfoPopup open/close/warm/ready,
  # shell themeReloadTimer. Migrated domain views must not grow new poll timers.
  ! rg -n '(^|[[:space:]])Timer[[:space:]]*\{' \
    "$production_dir/VolumePopup.qml" \
    "$production_dir/WifiPopup.qml" \
    "$production_dir/BluetoothPopup.qml" \
    "$production_dir/BatteryPopup.qml" \
    "$production_dir/SystemPopup.qml" \
    "$production_dir/MediaPopup.qml" \
    || fail 'migrated popups still own presentation-adjacent Timer blocks'
}

assert_variant_topbar_bindings_are_root_qualified() {
  local shell="$repo_root/home/configs/quickshell/shell.qml"
  local service

  for service in audio media cava power system niri network bluetooth; do
    rg -q "readonly property Services\\.${service^}Service shared${service^}Service:[[:space:]]*${service}Service" "$shell" \
      || fail "ShellRoot must expose ${service}Service under an unshadowed shared property"
    rg -U -q "Topbar[[:space:]]*\\{[^}]*${service}Service:[[:space:]]*root\\.shared${service^}Service" "$shell" \
      || fail "Topbar variant must bind ${service}Service from the ShellRoot"
  done
}
