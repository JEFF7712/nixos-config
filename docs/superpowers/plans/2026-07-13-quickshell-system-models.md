# Quickshell System Models Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Quickshell system behavior into one shell-owned deep module per domain while preserving every visual, interaction, profile, popup, and runtime behavior.

**Architecture:** `shell.qml` becomes the composition root for explicit `Scope`-based services under `home/configs/quickshell/services/`. Topbar and popups receive typed service references, render normalized state, and invoke typed actions. Ownership moves are committed before native backend substitutions so every step is independently revertible.

**Tech Stack:** Quickshell 0.3.0, QML/QtQuick, Quickshell native PipeWire/MPRIS/UPower/Networking/Bluetooth modules, `qmltestrunner`, Bash integration fixtures, Nix/just.

**Design spec:** `docs/superpowers/specs/2026-07-13-quickshell-system-models-design.md`

---

## File map

New production modules:

- `home/configs/quickshell/services/AudioService.qml`: default sink state and actions.
- `home/configs/quickshell/services/MediaService.qml`: player selection, metadata, playback state, detailed monitoring, and media actions.
- `home/configs/quickshell/services/CavaService.qml`: one demand-driven Cava process and parser.
- `home/configs/quickshell/services/PowerService.qml`: UPower, power profiles, charge threshold, and stasis state.
- `home/configs/quickshell/services/SystemService.qml`: metrics, host metadata, and host actions.
- `home/configs/quickshell/services/NiriService.qml`: workspaces, focused window, event stream, reconciliation, and actions.
- `home/configs/quickshell/services/NetworkService.qml`: Wi-Fi state, scanning, normalized networks, and actions.
- `home/configs/quickshell/services/BluetoothService.qml`: adapter state, normalized paired devices, and actions.
- `home/configs/quickshell/services/internal/*.js`: pure parsers and reducers owned by their domain modules.

New test infrastructure:

- `checks/quickshell-services.bash`: focused test orchestrator and structural ownership assertions.
- `tests/quickshell/unit/tst_*.qml`: pure QtQuick parser and reducer tests.
- `tests/quickshell/integration/*/shell.qml`: isolated real-Quickshell fixtures.
- `tests/quickshell/fixtures/bin/*`: deterministic fake executables for command and lifecycle tests.
- `tests/quickshell/fixtures/*.txt` and `*.json`: parser input fixtures.

Existing composition and views:

- `home/configs/quickshell/shell.qml`: instantiate exactly one service per domain and pass typed references.
- `home/configs/quickshell/Topbar.qml`: delete system adapters and consume services.
- `home/configs/quickshell/VolumePopup.qml`: consume AudioService.
- `home/configs/quickshell/MediaPopup.qml`: consume MediaService, AudioService fallback, and CavaService.
- `home/configs/quickshell/BatteryPopup.qml`: consume PowerService.
- `home/configs/quickshell/SystemPopup.qml`: consume SystemService and NiriService actions.
- `home/configs/quickshell/WifiPopup.qml`: consume NetworkService.
- `home/configs/quickshell/BluetoothPopup.qml`: consume BluetoothService.
- `home/configs/quickshell/InfoPopup.qml`: remain unchanged.
- `home/configs/quickshell/NotifService.qml`: remain the notification owner.
- `justfile`: add `quickshell-test` and include it in `check`.

Timing and state policies to preserve:

| Domain | Active cadence | Recovery and last-valid policy |
|---|---:|---|
| Audio ownership | 50 ms event debounce | one probe at a time; retain last volume across transient backend loss |
| Media ownership | position 1500 ms, interpolation 500 ms, refresh debounce 120 ms, only while `shown` | retain last complete record; bounded long-process retry only after unexpected exit |
| Cava | stream driven, 12 values | retries at 250/500/1000 ms; clear on intentional stop |
| Power adapters | 5000 ms shown, 30000 ms hidden | no overlap; retain native battery state through transient device churn |
| System metrics | 3000 ms; CPU delta sample window 200 ms; metadata 30000 ms while shown | publish only complete samples; retain last valid fields independently |
| Niri | event driven; reconcile every 30000 ms | retries at 250/500/1000 ms; retain last valid snapshots |
| Network ownership | 5000 ms shown, 20000 ms hidden; native discovery only while shown | retain discovery list when scanning stops; bar connectivity is independent |
| Bluetooth ownership | 4000 ms shown, 20000 ms hidden; native state reactive | clear busy on terminal state/disappearance; retain normalized list through transient churn |

## Execution rules

- Run `git status --short` before every task and preserve unrelated changes.
- Before lint or Nix evaluation, stage only the explicit paths for the current task. `qml-lint` uses `git ls-files`, and flake evaluation excludes untracked files. Re-run the same explicit `git add` as a scope check before committing.
- Never leave two active adapters for one migrated domain in a commit.
- Keep `InfoPopup.qml`, theme loading, `select-quickshell-theme`, and profile manifests unchanged during domain slices.
- For long-running adapters, record command signature, parent PID, and descendant PIDs. Do not use broad process-name counts as proof.
- Use `setpriv --pdeathsig TERM --` or a direct `exec` path until cleanup is proven under both fixture termination and the real profile-switch kill path.
- Run `just quickshell-test` and `just qml-lint` before every domain commit.
- Pure JS/QML reducers own deterministic backend-state tests. Real `quickshell -p` fixtures own service construction, typed wiring, process lifecycle, and command-backed action routing. Native singleton state and actions use read-only fixture probes plus guarded live smoke tests because Quickshell 0.3 globals are not replaceable. Views always retain concrete typed service references.
- Every integration fixture writes `ready` and then `result.json` with `passed` and `diagnostics`, calls `Qt.quit()`, and never tries to choose the process exit status itself. The Bash harness owns timeouts, validates the result, registers every fixture PID in an `EXIT` trap, and returns nonzero on failure.
- Before live tests, snapshot the active profile, variant, power profile, charge threshold, Wi-Fi state, Bluetooth state, and any player state the test changes. Restore changed state in a trap or finally path. Use `sharp` for the attached-popup regression and `everforest` for the floating-popup regression, then restore the starting profile and variant.
- After each migrated domain, reject `topbar` references from that domain's popup and require direct service wiring from `shell.qml`. Structural assertions inspect production QML only, exclude fixtures, reject stale `Quickshell.Io` imports, `Process`, `execDetached`, and domain command literals, and use an explicit per-file allowlist for presentation Timer ids.
- Every composition and consumer edited by a domain slice adds `import "services" as Services` and uses its concrete `Services.<Domain>Service` type. Local directory imports expose these QML component files without a separate URI module or singleton.

### Task 1: Add the two-layer service test harness

**Files:**
- Create: `checks/quickshell-services.bash`
- Create: `tests/quickshell/unit/tst_Harness.qml`
- Create: `tests/quickshell/integration/process-cleanup/shell.qml`
- Create: `tests/quickshell/fixtures/bin/qs-test-owned-process`
- Modify: `justfile`

- [ ] **Step 1: Add a failing pure-QML harness test**

Create `tests/quickshell/unit/tst_Harness.qml`:

```qml
import QtQuick
import QtTest

TestCase {
    name: "QuickshellHarness"

    function test_reactive_state_propagates_once() {
        const state = Qt.createQmlObject("import QtQuick; QtObject { property int value: 1 }", this);
        let changes = 0;
        state.valueChanged.connect(() => changes++);
        state.value = 2;
        compare(state.value, 2);
        compare(changes, 1);
        state.destroy();
    }
}
```

- [ ] **Step 2: Run the unit test directly and verify the missing recipe**

Run:

```fish
nix shell nixpkgs#qt6.qtdeclarative -c qmltestrunner -input tests/quickshell/unit -o -,txt
just quickshell-test
```

Expected: the QML test passes; `just quickshell-test` fails because the recipe does not exist.

- [ ] **Step 3: Add deterministic lifecycle fixtures**

Create `tests/quickshell/fixtures/bin/qs-test-owned-process` as a Bash script that requires `QS_TEST_STATE_DIR`, writes its PID and parent PID, starts one child sleep, writes the child PID, traps `TERM` and `EXIT`, terminates and waits for the child, then exits. Create `tests/quickshell/integration/process-cleanup/shell.qml` with one tracked `Process` running that executable and a startup marker file. Use `Quickshell.env("QS_TEST_STATE_DIR")`; do not touch live services.

Required fixture command shape:

```qml
Process {
    running: true
    command: ["qs-test-owned-process"]
}
```

- [ ] **Step 4: Add the test orchestrator**

Create `checks/quickshell-services.bash` with these exact phases:

```bash
run_unit_tests
run_process_cleanup_fixture
run_native_construction_probes
assert_no_view_processes_for_migrated_domains
```

Fail immediately with a clear diagnostic if the host `quickshell` executable is missing. `run_unit_tests` sets `QT_QPA_PLATFORM=offscreen` and runs `qmltestrunner`. `run_process_cleanup_fixture` creates a temporary state directory, prepends `tests/quickshell/fixtures/bin` to `PATH`, and runs four cases: destroy a service through a `Loader`; trigger one real soft and one hard generation reload from inside `quickshell -p`; terminate the fixture shell; and send the same TERM kill shape used by profile transition to an isolated fixture. For every generation, record PID, PPID, start time, command signature, and descendants to avoid PID-reuse false positives. Verify all recorded processes exit within five seconds. The same fixture drives a second start while the first process is running and repeated failure events to prove overlap suppression, one coalesced retry timer, bounded attempts, and no restart after intentional destruction. Native probes are read-only, run only when their session bus/backend is present, and report an explicit skip otherwise; hermetic reducer and command-backed fixtures remain mandatory. The structural phase initially records current command signatures without enforcing future-domain ownership.

- [ ] **Step 5: Add the just recipe**

Add to `justfile`:

```just
quickshell-test:
  QT_QPA_PLATFORM=offscreen nix shell nixpkgs#qt6.qtdeclarative -c bash checks/quickshell-services.bash
```

Do not add it to `just check` until the harness passes reliably twice.

- [ ] **Step 6: Verify the harness twice**

Run:

```fish
just quickshell-test
just quickshell-test
just qml-lint
```

Expected: both harness runs pass, the fixture leaves no recorded process alive, and QML lint passes.

- [ ] **Step 7: Add stable QML validation to the broad check**

Insert these lines in `just check` immediately after `just wallpaper-script-check`:

```just
  just qml-lint
  just quickshell-test
```

- [ ] **Step 8: Commit the harness**

```fish
git add justfile checks/quickshell-services.bash tests/quickshell/unit/tst_Harness.qml tests/quickshell/integration/process-cleanup/shell.qml tests/quickshell/fixtures/bin/qs-test-owned-process
git commit -m "Add Quickshell service test harness"
```

### Task 2: Centralize audio ownership with the current backend

**Files:**
- Create: `home/configs/quickshell/services/AudioService.qml`
- Create: `tests/quickshell/integration/audio-service/shell.qml`
- Create: `tests/quickshell/fixtures/bin/wpctl`
- Create: `tests/quickshell/fixtures/bin/pw-mon`
- Create: `tests/quickshell/fixtures/bin/pavucontrol`
- Modify: `home/configs/quickshell/shell.qml`
- Modify: `home/configs/quickshell/Topbar.qml`
- Modify: `home/configs/quickshell/VolumePopup.qml`
- Modify: `home/configs/quickshell/MediaPopup.qml`
- Modify: `checks/quickshell-services.bash`

- [ ] **Step 1: Write failing structural audio assertions**

Extend `checks/quickshell-services.bash` to require, after this task:

```bash
assert_absent_outside_service 'wpctl' home/configs/quickshell/Topbar.qml home/configs/quickshell/VolumePopup.qml home/configs/quickshell/MediaPopup.qml
assert_absent_outside_service 'pw-mon' home/configs/quickshell/Topbar.qml home/configs/quickshell/VolumePopup.qml home/configs/quickshell/MediaPopup.qml
assert_no_qml_process home/configs/quickshell/VolumePopup.qml
assert_single_service_instance AudioService home/configs/quickshell/shell.qml
```

Run `just quickshell-test`. Expected: FAIL because the old audio adapters remain.

- [ ] **Step 2: Add a deterministic audio integration fixture**

The fake `wpctl` must support `get-volume`, `set-volume`, and `set-mute`, storing volume and mute under `QS_TEST_STATE_DIR`. The fake `pw-mon` tails an events FIFO. Fake `pavucontrol` appends its argv to the action log. The integration shell instantiates one AudioService and two probe consumers, drives an external event, asserts both consumers observe one update, invokes each action once, and writes the standard result file after validating one command record per action.

- [ ] **Step 3: Implement AudioService with the proven adapter**

Use the exact public contract from the design:

```qml
Scope {
    readonly property bool available
    readonly property int volumePercent
    readonly property bool muted

    function setVolume(percent: int): void
    function adjustVolume(direction: int): void
    function toggleMute(): void
    function openMixer(): void
}
```

Move the current `wpctl` probe, `pw-mon` subscription, 50 ms debounce, two-percent wheel step, 0 through 100 clamp, and `pavucontrol` launch into this file without changing behavior.

- [ ] **Step 4: Wire one typed instance into every sink consumer**

In `shell.qml`:

```qml
Services.AudioService {
    id: audioService
}
```

Add `import "services" as Services` to shell and the three consumers, then add `required property Services.AudioService audioService` to Topbar, VolumePopup, and MediaPopup. Replace VolumePopup's string `volumeLevel` and action signals with typed bindings while mapping `available: false` back to the existing `"-"` display. Preserve immediate slider/wheel feedback by letting AudioService expose the commanded clamped value until the backend confirms it. MediaPopup keeps player-volume policy, but its 0.0 through 1.0 system fallback must read `audioService.volumePercent / 100.0` and call `audioService.setVolume(Math.round(fraction * 100))`, preserving the 0 through 100 clamp.

- [ ] **Step 5: Delete all external audio adapters**

Delete the volume field from Topbar's composite poll, `volumeProbe`, `volumeDebounce`, `volumeSubscribeProc`, Topbar audio command construction, popup audio signals routed through Topbar, and MediaPopup `wpctl` reads and writes.

- [ ] **Step 6: Run focused verification**

```fish
just quickshell-test
just qml-lint
just eval laptop
```

Expected: all pass. The structural test finds `wpctl` and `pw-mon` only in AudioService and fixture files.

- [ ] **Step 7: Live audio smoke test**

Record the current shell PID and audio process ancestry. Verify external `wpctl` changes, keyboard volume actions, bar wheel, popup drag, mute, mixer launch, popup Escape, outside click, and profile reload. Confirm one `pw-mon` adapter tree and no orphaned previous tree.

- [ ] **Step 8: Commit audio ownership**

```fish
git add home/configs/quickshell/services/AudioService.qml home/configs/quickshell/shell.qml home/configs/quickshell/Topbar.qml home/configs/quickshell/VolumePopup.qml home/configs/quickshell/MediaPopup.qml checks/quickshell-services.bash tests/quickshell/integration/audio-service/shell.qml tests/quickshell/fixtures/bin/wpctl tests/quickshell/fixtures/bin/pw-mon tests/quickshell/fixtures/bin/pavucontrol
git commit -m "Centralize Quickshell audio ownership"
```

### Task 3: Replace the audio backend with native PipeWire

**Files:**
- Modify: `home/configs/quickshell/services/AudioService.qml`
- Create: `home/configs/quickshell/services/internal/AudioReducer.js`
- Create: `tests/quickshell/unit/tst_AudioReducer.qml`
- Create: `tests/quickshell/integration/audio-native/shell.qml`
- Modify: `checks/quickshell-services.bash`

- [ ] **Step 1: Add failing native audio contract checks**

Require `AudioService.qml` to import `Quickshell.Services.Pipewire`, instantiate `PwObjectTracker`, and contain no `Process`, `wpctl`, or `pw-mon`. Add backend-free reducer tests for availability, null-sink last-value retention, clamping, and mute propagation. Run `just quickshell-test`; expect failure.

- [ ] **Step 2: Implement the native backend without changing the interface**

Track the changing `Pipewire.defaultAudioSink`:

```qml
readonly property var sink: Pipewire.defaultAudioSink

PwObjectTracker {
    objects: [root.sink]
}
```

Define availability from `Pipewire.ready`, non-null sink/audio, and sink readiness. Cache the last valid percentage across a transient null sink. Set `sink.audio.volume` with a 0.0 through 1.0 clamp and `sink.audio.muted` for mute. Keep `openMixer()` detached.

- [ ] **Step 3: Verify native state and recovery**

```fish
just quickshell-test
just qml-lint
just eval laptop
```

The native fixture only proves construction, typed properties, and safe reads against the current session. Then live-test external `wpctl` changes, mute changes, and default-sink replacement without changing the public interface. Treat a full WirePlumber/PipeWire restart as optional evidence only when it is non-disruptive. Keep the Task 2 command-backed fixture as durable evidence for the unchanged public contract; do not pretend it drives the native singleton.

- [ ] **Step 4: Confirm old processes are gone**

Assert the live shell has no `pw-mon` descendant and no recurring `wpctl get-volume` process. Confirm bar, VolumePopup, and MediaPopup fallback show the same sink state.

- [ ] **Step 5: Commit the backend substitution**

```fish
git add home/configs/quickshell/services/AudioService.qml home/configs/quickshell/services/internal/AudioReducer.js tests/quickshell/unit/tst_AudioReducer.qml tests/quickshell/integration/audio-native/shell.qml checks/quickshell-services.bash
git commit -m "Use native PipeWire audio state"
```

### Task 4: Centralize media ownership with playerctl

**Files:**
- Create: `home/configs/quickshell/services/MediaService.qml`
- Create: `home/configs/quickshell/services/internal/MediaParser.js`
- Create: `tests/quickshell/unit/tst_MediaParser.qml`
- Create: `tests/quickshell/integration/media-service/shell.qml`
- Create: `tests/quickshell/fixtures/bin/playerctl`
- Modify: `home/configs/quickshell/shell.qml`
- Modify: `home/configs/quickshell/Topbar.qml`
- Modify: `home/configs/quickshell/MediaPopup.qml`
- Modify: `checks/quickshell-services.bash`

- [ ] **Step 1: Write failing parser and ownership tests**

Cover one complete metadata record, missing metadata fields, delimiter text inside a title, empty output, nonzero exit, player disappearance, and preservation of the last complete state. The fake `playerctl` supports `--follow`, status/metadata/settings reads, every owned action, a FIFO for state changes, and an argv log. Commit a golden selection-policy fixture for one player, playing preference, paused fallback, last-selected retention, capability changes, and disappearance. Require `playerctl` to appear only in MediaService and test fixtures.

- [ ] **Step 2: Implement the pure parser**

`MediaParser.js` returns a complete normalized object or `null`; it never mutates QML state. The installed playerctl 2.4.1 exposes `--format`, not a documented JSON mode. Use a length-prefixed or explicitly escaped per-field record format. Tests must include newlines, the chosen delimiter, backslashes, and Unicode inside metadata so arbitrary titles cannot corrupt framing.

- [ ] **Step 3: Implement MediaService with an AudioService dependency**

Implement every exact property and action in the design. Move `playerctl --follow`, position polling, settings polling, debounce, and command construction into the service. `detailedMonitoring` controls position work and is bound from `mediaPopup.shown`.

- [ ] **Step 4: Wire views and delete media behavior from them**

Instantiate MediaService once in shell with `audioService: audioService`. Pass it to Topbar and MediaPopup. Retain only seek-drag presentation state in MediaPopup. Delete its `Process` blocks, polling timers, refresh debounce, and player commands. Delete Topbar's media process and actions.

- [ ] **Step 5: Verify and smoke-test selection semantics**

```fish
just quickshell-test
just qml-lint
just eval laptop
```

Live scenarios: one playing player, one paused player, two players with one playing, selected-player disappearance, play/pause, next, previous, seek, shuffle, loop, player volume, and AudioService fallback.

- [ ] **Step 6: Commit media ownership**

```fish
git add home/configs/quickshell/services/MediaService.qml home/configs/quickshell/services/internal/MediaParser.js tests/quickshell/unit/tst_MediaParser.qml tests/quickshell/integration/media-service/shell.qml tests/quickshell/fixtures/bin/playerctl home/configs/quickshell/shell.qml home/configs/quickshell/Topbar.qml home/configs/quickshell/MediaPopup.qml checks/quickshell-services.bash
git commit -m "Centralize Quickshell media ownership"
```

### Task 5: Substitute native MPRIS after parity proof

**Files:**
- Modify: `home/configs/quickshell/services/MediaService.qml`
- Create: `home/configs/quickshell/services/internal/MediaSelector.js`
- Create: `tests/quickshell/unit/tst_MediaSelector.qml`
- Create: `tests/quickshell/integration/media-native/shell.qml`
- Modify: `checks/quickshell-services.bash`

- [ ] **Step 1: Encode the proven selection policy as failing tests**

Use `MediaSelector.js` with fake player snapshots to cover one player, multiple players, paused players, capability changes, and disappearance. Expected selection and action routing must come from Task 4's committed golden observations of bare playerctl and `--follow`; do not invent playing preference or last-selected retention unless playerctl actually demonstrates it.

- [ ] **Step 2: Replace playerctl internals with MPRIS**

Import `Quickshell.Services.Mpris`, select from `Mpris.players.values`, map playback enums to the existing status strings, use guarded properties such as `trackTitle`, map native `shuffleSupported` and `loopSupported` into the public `canShuffle` and `canLoop` flags, and call actions only when their capability flags permit them. While `detailedMonitoring && playing`, use a Timer to call `player.positionChanged()`.

- [ ] **Step 3: Verify parity or intentionally defer**

The native fixture proves read-only construction and property mapping against the current session. Run focused tests and repeat the Task 4 live selection matrix. If parity fails, revert only this uncommitted task and add an "MPRIS deferred" note with evidence to the final implementation report; do not create a code commit for an unapplied backend. Do not weaken the public interface or commit changed selection behavior.

- [ ] **Step 4: Commit only on parity**

```fish
git add home/configs/quickshell/services/MediaService.qml home/configs/quickshell/services/internal/MediaSelector.js tests/quickshell/unit/tst_MediaSelector.qml tests/quickshell/integration/media-native/shell.qml checks/quickshell-services.bash
git commit -m "Use native MPRIS media state"
```

### Task 6: Extract Cava lifecycle and parsing

**Files:**
- Create: `home/configs/quickshell/services/CavaService.qml`
- Create: `home/configs/quickshell/services/internal/CavaParser.js`
- Create: `tests/quickshell/unit/tst_CavaParser.qml`
- Create: `tests/quickshell/integration/cava-service/shell.qml`
- Create: `tests/quickshell/fixtures/bin/cava`
- Modify: `home/configs/quickshell/shell.qml`
- Modify: `home/configs/quickshell/Topbar.qml`
- Modify: `home/configs/quickshell/MediaPopup.qml`
- Modify: `checks/quickshell-services.bash`

- [ ] **Step 1: Write failing Cava parser tests**

Cover empty fields, nonnumeric fields, CRLF, partial chunks, multiple records, value clamping, exactly 12 bars from `cava-bar.conf`, shorter-frame padding, longer-frame truncation, and clearing values on stop. Compile-spike `readonly property list<int>` under Quickshell 0.3; if unsupported, amend the spec before using a JS array contract. The fake `cava` emits controlled chunks from a FIFO and records starts/exits.

- [ ] **Step 2: Implement CavaService**

Expose `playing`, `requested`, and `readonly property list<int> values`. Own the resolved config path, `setpriv --pdeathsig TERM -- cava`, chunk buffering, complete-record parsing, single-instance guard, three retries at 250 ms, 500 ms, and 1000 ms, cancellation after recovery or intentional stop, and clear-on-stop behavior.

- [ ] **Step 3: Wire exact demand semantics**

Set `playing` from MediaService. Add `readonly property bool cavaRequested: mediaPill.visible` to Topbar and bind `cavaService.requested: topbar.cavaRequested || mediaPopup.active` in shell. Do not use retained `showMedia` alone, `mapped`, or `warming`. The deletion test removes this presentation-demand binding with the Topbar instance, so popup demand remains independent.

- [ ] **Step 4: Verify process ancestry and UI parity**

Run tests and lint. Live-test playing, paused, popup-only, bar-only, closing animation, shell reload, and profile-switch termination. Confirm one Cava tree when requested and none otherwise.

- [ ] **Step 5: Commit Cava extraction**

```fish
git add home/configs/quickshell/services/CavaService.qml home/configs/quickshell/services/internal/CavaParser.js tests/quickshell/unit/tst_CavaParser.qml tests/quickshell/integration/cava-service/shell.qml tests/quickshell/fixtures/bin/cava home/configs/quickshell/shell.qml home/configs/quickshell/Topbar.qml home/configs/quickshell/MediaPopup.qml checks/quickshell-services.bash
git commit -m "Extract Quickshell Cava lifecycle"
```

### Task 7: Extract power and battery behavior, then substitute native state

**Files:**
- Create: `home/configs/quickshell/services/PowerService.qml`
- Create: `home/configs/quickshell/services/internal/PowerParser.js`
- Create: `tests/quickshell/unit/tst_PowerParser.qml`
- Create: `tests/quickshell/integration/power-service/shell.qml`
- Create: `tests/quickshell/integration/power-native/shell.qml`
- Create: `tests/quickshell/fixtures/bin/upower`
- Create: `tests/quickshell/fixtures/bin/powerprofilesctl`
- Create: `tests/quickshell/fixtures/bin/stasis`
- Modify: `home/configs/quickshell/shell.qml`
- Modify: `home/configs/quickshell/Topbar.qml`
- Modify: `home/configs/quickshell/BatteryPopup.qml`
- Modify: `checks/quickshell-services.bash`

- [ ] **Step 1: Add failing normalized-state tests**

Cover no battery, charging, discharging, full, time to empty/full, health, profile enum mapping, missing power-profiles daemon, threshold absent/read-only/writable, stasis yes/no/malformed output, and preservation of last valid state.

- [ ] **Step 2: Move the current adapters behind PowerService**

Implement the exact public contract from the design using the current `upower`, `powerprofilesctl`, threshold-file, and `stasis` behavior. Give the threshold path a production default and a fixture-only override so tests never write `/sys`. The fake executables record invocations and return deterministic states.

- [ ] **Step 3: Wire views and delete duplicate polling**

Pass one typed PowerService instance. Remove battery/profile fields from Topbar's composite poll, all BatteryPopup processes and polling timers, and all power command construction from the views. Prevent overlapping probes and refresh after owned actions.

- [ ] **Step 4: Verify and commit the ownership move**

Run focused tests, lint, and eval. Exercise every action against the fake commands and threshold file, then live-smoke the unchanged current backend.

```fish
git add home/configs/quickshell/services/PowerService.qml home/configs/quickshell/services/internal/PowerParser.js tests/quickshell/unit/tst_PowerParser.qml tests/quickshell/integration/power-service/shell.qml tests/quickshell/fixtures/bin/upower tests/quickshell/fixtures/bin/powerprofilesctl tests/quickshell/fixtures/bin/stasis home/configs/quickshell/shell.qml home/configs/quickshell/Topbar.qml home/configs/quickshell/BatteryPopup.qml checks/quickshell-services.bash
git commit -m "Centralize Quickshell power ownership"
```

- [ ] **Step 5: Add failing native-state assertions**

Require `UPower.displayDevice` and `PowerProfiles` in PowerService while retaining the threshold and stasis adapters. Pure parser/reducer tests cover enum normalization, and a separate read-only native fixture covers construction. PowerProfiles daemon absence cannot be inferred reliably from the 0.3 singleton because it defaults to Balanced and has no availability property; require shell reload after daemon absence and do not fabricate an error.

- [ ] **Step 6: Substitute native battery and profile state**

Use `UPower.displayDevice` and `PowerProfiles`. Normalize their enums into the exact design strings and numeric values. Keep threshold and stasis subprocess ownership unchanged. Do not promise native write errors that Quickshell does not expose.

- [ ] **Step 7: Verify and commit the native substitution**

Run `just quickshell-test`, `just qml-lint`, and `just eval laptop`. Live-test profile click/wheel, charge-limit toggle, idle-inhibit toggle, unplug/plug state, popup Escape/outside click, and profile reload.

```fish
git add home/configs/quickshell/services/PowerService.qml tests/quickshell/unit/tst_PowerParser.qml tests/quickshell/integration/power-native/shell.qml checks/quickshell-services.bash
git commit -m "Use native Quickshell power state"
```

### Task 8: Extract system metrics and host actions

**Files:**
- Create: `home/configs/quickshell/services/SystemService.qml`
- Create: `home/configs/quickshell/services/internal/SystemParser.js`
- Create: `tests/quickshell/unit/tst_SystemParser.qml`
- Create: `tests/quickshell/integration/system-service/shell.qml`
- Create: `tests/quickshell/fixtures/bin/lock-screen`
- Create: `tests/quickshell/fixtures/bin/systemctl`
- Modify: `home/configs/quickshell/shell.qml`
- Modify: `home/configs/quickshell/Topbar.qml`
- Modify: `home/configs/quickshell/SystemPopup.qml`
- Modify: `checks/quickshell-services.bash`

- [ ] **Step 1: Add failing parser tests**

Cover the first CPU sample, valid delta, zero delta, malformed `/proc/stat`, missing memory fields, disk failure, missing generation symlink, and complete host metadata. Fake `lock-screen` and `systemctl` accept only the exact owned argument arrays and append calls to the fixture action log; all other arguments fail.

- [ ] **Step 2: Implement one coordinated SystemService**

Expose the exact typed interface from the spec. Own CPU sampling, memory/disk collection, static metadata refresh, non-overlap guards, last-complete-state behavior, and lock/suspend/reboot/poweroff command construction.

- [ ] **Step 3: Wire views and delete duplicate polling**

Pass one instance to Topbar and SystemPopup. Bind SystemPopup host name, kernel, uptime, generation, RAM, CPU, and disk fields directly to SystemService. Remove remaining metrics from Topbar's composite poll, remove SystemPopup's process and timer, and replace direct host commands with typed actions. Each popup action must call `systemPopup.close()` immediately after invoking the service to preserve current close-on-action behavior. Leave SystemPopup's existing logout command untouched and make the structural checker require exactly that one documented Niri command occurrence until Task 9. Do not move that command into SystemService or add a temporary shell adapter.

- [ ] **Step 4: Verify and commit**

Run focused tests, lint, eval, compare displayed metrics to `/proc`, `df`, and hostname tools, and smoke-test only non-destructive actions. Verify destructive action command construction through the isolated fixture, not on the live desktop.

```fish
git add home/configs/quickshell/services/SystemService.qml home/configs/quickshell/services/internal/SystemParser.js tests/quickshell/unit/tst_SystemParser.qml tests/quickshell/integration/system-service/shell.qml tests/quickshell/fixtures/bin/lock-screen tests/quickshell/fixtures/bin/systemctl home/configs/quickshell/shell.qml home/configs/quickshell/Topbar.qml home/configs/quickshell/SystemPopup.qml checks/quickshell-services.bash
git commit -m "Extract Quickshell system model"
```

### Task 9: Extract Niri state and actions

**Files:**
- Create: `home/configs/quickshell/services/NiriService.qml`
- Create: `home/configs/quickshell/services/internal/NiriParser.js`
- Create: `tests/quickshell/unit/tst_NiriParser.qml`
- Create: `tests/quickshell/integration/niri-service/shell.qml`
- Create: `tests/quickshell/fixtures/bin/niri`
- Modify: `home/configs/quickshell/shell.qml`
- Modify: `home/configs/quickshell/Topbar.qml`
- Modify: `home/configs/quickshell/SystemPopup.qml`
- Modify: `checks/quickshell-services.bash`

- [ ] **Step 1: Add failing snapshot and event tests**

Cover workspace order, occupancy, active/focused selection, urgent state, focused-window title/app ID, missing window, malformed and partial JSON, every consumed event class, reconciliation, stream exit, coalesced retry, and last-valid snapshot preservation.

- [ ] **Step 2: Implement the Niri adapter**

Run direct `niri msg -j workspaces`, direct `niri msg -j focused-window`, and `['setpriv', '--pdeathsig', 'TERM', '--', 'niri', 'msg', '-j', 'event-stream']` without a persistent shell wrapper. The fake `niri` supports those snapshots, newline-delimited event JSON through a FIFO, and the exact owned action arrays. Buffer partial chunks until a newline, parse only complete records, guard snapshots against overlapping runs, reconcile every 30 seconds, and retry the stream at 250 ms, 500 ms, and 1000 ms before exposing failure. Cancel retry when healthy or destroyed.

- [ ] **Step 3: Move every Niri action**

Implement focus workspace, adjacent focus, and quit session. Retarget Topbar's workspace Repeater, occupancy/active roles, click ids, and indicator x-position to the normalized model and active model index rather than assuming workspace id minus one. Wire Topbar workspace clicks/wheel and SystemPopup logout to these typed actions, with logout still closing the popup immediately. Delete all Niri processes, timers, parser state, and command construction from Topbar. Remove the temporary structural exemption and make the test fail if any Niri command remains in SystemPopup.

- [ ] **Step 4: Verify process cleanup and state parity**

Run focused tests, lint, and eval. Compare live workspace order, occupancy, focus, focused title, click/wheel navigation, window changes, stream restart, shell exit, and profile-switch cleanup. Record one stream process tree.

- [ ] **Step 5: Commit Niri extraction**

```fish
git add home/configs/quickshell/services/NiriService.qml home/configs/quickshell/services/internal/NiriParser.js tests/quickshell/unit/tst_NiriParser.qml tests/quickshell/integration/niri-service/shell.qml tests/quickshell/fixtures/bin/niri home/configs/quickshell/shell.qml home/configs/quickshell/Topbar.qml home/configs/quickshell/SystemPopup.qml checks/quickshell-services.bash
git commit -m "Extract Quickshell Niri model"
```

### Task 10: Centralize Wi-Fi ownership, then substitute native Networking

**Files:**
- Create: `home/configs/quickshell/services/NetworkService.qml`
- Create: `home/configs/quickshell/services/internal/NetworkParser.js`
- Create: `home/configs/quickshell/services/internal/NetworkReducer.js`
- Create: `tests/quickshell/unit/tst_NetworkReducer.qml`
- Create: `tests/quickshell/integration/network-service/shell.qml`
- Create: `tests/quickshell/integration/network-native/shell.qml`
- Create: `tests/quickshell/fixtures/bin/nmcli`
- Create: `tests/quickshell/fixtures/bin/kitty`
- Modify: `home/configs/quickshell/shell.qml`
- Modify: `home/configs/quickshell/Topbar.qml`
- Modify: `home/configs/quickshell/WifiPopup.qml`
- Modify: `checks/quickshell-services.bash`

- [ ] **Step 1: Add failing parser, normalization, and action tests**

Cover current nmcli output framing plus no device, multiple devices, enabled/disabled radio, active SSID, strongest-AP deduplication, descending signal order, eight-entry limit, known/open/secured roles, busy state, no-secrets fallback, and daemon-absent reload requirement. Fake `nmcli` supports only the current query, radio, and connect arrays; fake `kitty` records the exact settings and interactive-connect argv.

- [ ] **Step 2: Move the current adapters behind NetworkService**

Implement the exact public contract from the design using the current nmcli query, polling cadence, parsing, radio action, connect action, and settings command. Preserve current ordering, eight-entry limit, and busy clearing exactly.

- [ ] **Step 3: Wire the bar and popup, then delete duplicates**

Bind `scanningRequested` to `wifiPopup.shown`. Replace Topbar connectivity state and right-click command with NetworkService. Delete all processes, timers, parsing, and commands from WifiPopup and remove network state from Topbar's composite poll.

- [ ] **Step 4: Verify and commit the ownership move**

Run focused tests, lint, and eval. Exercise actions against fakes and live-smoke the unchanged nmcli behavior.

```fish
git add home/configs/quickshell/services/NetworkService.qml home/configs/quickshell/services/internal/NetworkParser.js home/configs/quickshell/services/internal/NetworkReducer.js tests/quickshell/unit/tst_NetworkReducer.qml tests/quickshell/integration/network-service/shell.qml tests/quickshell/fixtures/bin/nmcli tests/quickshell/fixtures/bin/kitty home/configs/quickshell/shell.qml home/configs/quickshell/Topbar.qml home/configs/quickshell/WifiPopup.qml checks/quickshell-services.bash
git commit -m "Centralize Quickshell network ownership"
```

- [ ] **Step 5: Add failing native construction and reduction checks**

Create a read-only native fixture and require the service to import `Quickshell.Networking` with no polling Process. Pure tests drive snapshots through NetworkReducer; they do not claim to replace the native singleton.

- [ ] **Step 6: Substitute the native backend**

Select the first Wi-Fi device after stable sort by device name/path. Keep bar connectivity derived from `Networking.connectivity` or device connection state, not the popup scan list. Enable scanning only while `scanningRequested`, retain the last normalized discovery list when scanning stops, deduplicate SSIDs by strongest AP, sort descending, and expose eight entries. Maintain an internal SSID-to-native-object map for actions while exposing only scalar public roles. Known networks connect natively. Attach `Connections` for native `connectionFailed(NoSecrets)` and route unknown/no-secrets cases to detached `kitty -e nmtui-connect`. Require a shell reload after NetworkManager daemon absence.

- [ ] **Step 7: Verify and commit the native substitution**

Run focused tests, lint, and eval. Live-test radio toggle, known connection, unknown interactive path without entering credentials, active state while scanning is off, scanning only while shown, Escape/outside click, device churn, and shell reload. Restore radio and connection state afterward.

```fish
git add home/configs/quickshell/services/NetworkService.qml home/configs/quickshell/services/internal/NetworkReducer.js tests/quickshell/unit/tst_NetworkReducer.qml tests/quickshell/integration/network-native/shell.qml checks/quickshell-services.bash
git commit -m "Use native Quickshell network state"
```

### Task 11: Centralize Bluetooth ownership, then substitute native Bluetooth

**Files:**
- Create: `home/configs/quickshell/services/BluetoothService.qml`
- Create: `home/configs/quickshell/services/internal/BluetoothParser.js`
- Create: `home/configs/quickshell/services/internal/BluetoothReducer.js`
- Create: `tests/quickshell/unit/tst_BluetoothReducer.qml`
- Create: `tests/quickshell/integration/bluetooth-service/shell.qml`
- Create: `tests/quickshell/integration/bluetooth-native/shell.qml`
- Create: `tests/quickshell/fixtures/bin/busctl`
- Create: `tests/quickshell/fixtures/bin/blueman-manager`
- Modify: `home/configs/quickshell/shell.qml`
- Modify: `home/configs/quickshell/Topbar.qml`
- Modify: `home/configs/quickshell/BluetoothPopup.qml`
- Modify: `checks/quickshell-services.bash`

- [ ] **Step 1: Add failing parser, normalization, and action tests**

Cover current busctl output plus no adapter, powered state, paired filtering, connected-first ordering, alphabetical tie-break, busy state, disappearance while busy, connect/disconnect action routing, log-only native failures, and daemon-absent reload requirement. Fake `busctl` accepts only the current tree/get/set/call argument arrays and records state; fake `blueman-manager` records launch.

- [ ] **Step 2: Move the current adapters behind BluetoothService**

Implement the exact public contract from the design using the current busctl query, polling cadence, adapter toggle, device action, busy clearing, and manager command.

- [ ] **Step 3: Wire and delete view adapters**

Pass one typed instance to Topbar and BluetoothPopup. Replace the bar manager command and popup state/actions. Delete all BlueZ processes, polling, parsing, and command construction from BluetoothPopup.

- [ ] **Step 4: Verify and commit the ownership move**

Run focused tests, lint, and eval. Exercise every action against the fake commands and live-smoke unchanged busctl behavior.

```fish
git add home/configs/quickshell/services/BluetoothService.qml home/configs/quickshell/services/internal/BluetoothParser.js home/configs/quickshell/services/internal/BluetoothReducer.js tests/quickshell/unit/tst_BluetoothReducer.qml tests/quickshell/integration/bluetooth-service/shell.qml tests/quickshell/fixtures/bin/busctl tests/quickshell/fixtures/bin/blueman-manager home/configs/quickshell/shell.qml home/configs/quickshell/Topbar.qml home/configs/quickshell/BluetoothPopup.qml checks/quickshell-services.bash
git commit -m "Centralize Quickshell Bluetooth ownership"
```

- [ ] **Step 5: Add failing native construction and reduction checks**

Create a read-only native fixture and require `Quickshell.Bluetooth` with no busctl polling Process. Pure tests drive fake snapshots through BluetoothReducer; native failures remain log-only.

- [ ] **Step 6: Substitute the native backend**

Use `Quickshell.Bluetooth.defaultAdapter`, filter paired devices, normalize them into the specified scalar roles, derive connected count, set adapter enabled state, toggle device connection, and keep `openManager()`. Maintain an internal device-id-to-native-object map for actions. Derive busy from native device state, clear it on a terminal state or disappearance, do not fabricate native error text, and require shell reload after BlueZ daemon absence.

- [ ] **Step 7: Verify and commit the native substitution**

Run focused tests, lint, and eval. Live-test adapter toggle, paired device order, connect/disconnect, busy indicators, manager launch, Escape/outside click, device churn, and shell reload. Restore adapter and connection state afterward.

```fish
git add home/configs/quickshell/services/BluetoothService.qml home/configs/quickshell/services/internal/BluetoothReducer.js tests/quickshell/unit/tst_BluetoothReducer.qml tests/quickshell/integration/bluetooth-native/shell.qml checks/quickshell-services.bash
git commit -m "Use native Quickshell Bluetooth state"
```

### Task 12: Enforce the deletion test and complete the architecture

**Files:**
- Create: `tests/quickshell/integration/popup-only/shell.qml`
- Modify: `home/configs/quickshell/shell.qml`
- Modify: `home/configs/quickshell/Topbar.qml`
- Modify: `checks/quickshell-services.bash`
- Modify: `checks/profile-transition.bash`

- [ ] **Step 1: Add the failing popup-only composition fixture**

Create a fixture that instantiates the same domain services and migrated popups without importing or referencing Topbar or starting a notification server. It must bind and read each typed service from its popup. Exercise actions only for command-backed services through the existing recorders. Native singleton actions remain covered by their guarded domain smoke tests; the deletion fixture must never mutate session, radio, power, or Bluetooth state. Write the standard result file and exit normally.

- [ ] **Step 2: Add final structural invariants**

Require:

```text
Topbar and migrated popups contain no Process blocks.
Migrated views contain no execDetached calls or domain command literals.
Each domain service is instantiated exactly once in shell.qml.
No popup or service references the topbar id.
Production shell references the Topbar type only in its presentation instantiation and presentation-demand bindings.
The old composite stats command is absent.
Only documented presentation timers remain in views.
```

- [ ] **Step 3: Remove final Topbar-owned state**

Delete obsolete scalar fields, helper actions, and imports from Topbar. Bind notification count directly from `NotifService.count` in shell instead of `NotificationsPopup.unreadCount`. Keep rendering, signals that open popups, and all visual configuration unchanged.

- [ ] **Step 4: Protect the profile and popup contracts**

Extend `checks/profile-transition.bash` to assert the existing pending/runtime Quickshell theme selection remains unchanged. Do not edit `InfoPopup.qml`. Snapshot the starting profile and variant, smoke-test `sharp` for attached popups and `everforest` for floating popups, cover prewarm, frozen height, focus, Escape, outside click, and startup no-flash behavior, then restore the snapshot even on failure.

- [ ] **Step 5: Run the full deletion-test fixture**

```fish
just quickshell-test
just qml-lint
```

Expected: the popup-only fixture loads and every structural invariant passes.

- [ ] **Step 6: Commit architecture completion**

```fish
git add tests/quickshell/integration/popup-only/shell.qml home/configs/quickshell/shell.qml home/configs/quickshell/Topbar.qml checks/quickshell-services.bash checks/profile-transition.bash
git commit -m "Complete Quickshell presentation split"
```

### Task 13: Final verification and independent review

**Files:**
- Review only unless verification exposes a defect.

- [ ] **Step 1: Run focused and repository verification**

```fish
just quickshell-test
just qml-lint
just eval laptop
just check
just build laptop
```

Expected: every command exits 0.

- [ ] **Step 2: Check for a competing switch**

Inspect the holder of `/run/nixos-auto-update.lock` and active NixOS switch/update units. If another switch is active, do not start one. Record that activation is deferred. Otherwise run `just switch` and require exit 0.

- [ ] **Step 3: Execute the live smoke matrix**

For every migrated domain test external change, bar interaction, popup interaction, unavailable/recovery behavior, popup focus/Escape/outside click, shell reload, and profile switch. Record service process ancestry before and after. Confirm no old command signatures or orphan descendants remain.

- [ ] **Step 4: Run an independent implementation review**

Use a different model or model family from the primary implementer. Require it to inspect the diff, spec, plan, tests, live process evidence, and commit series. Address every confirmed high or medium finding in a new logical commit and rerun affected verification.

- [ ] **Step 5: Run final clean verification after review fixes**

```fish
just quickshell-test
just qml-lint
just eval laptop
just check
just build laptop
git status --short
git log --oneline (git log -1 --format=%H -- docs/superpowers/plans/2026-07-13-quickshell-system-models.md)..HEAD
```

Expected: validations pass, the worktree contains no task-related uncommitted changes, and the log shows one logical commit per harness, ownership move, backend substitution, and domain slice.
