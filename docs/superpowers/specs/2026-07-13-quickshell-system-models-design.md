# Quickshell System Models Design

## Objective

Move system behavior out of Quickshell presentation files and into deep, reusable QML modules with narrow typed interfaces. Topbar and popup files will render state, retain presentation-specific interaction state, and invoke domain actions. This refactor preserves appearance, interactions, keybindings, desktop-profile behavior, popup behavior, and runtime semantics.

The deletion test is the primary acceptance criterion: removing the `Topbar` instance and its composition-root bindings, then deleting `Topbar.qml`, must remove only the bar UI. System state and behavior required by popups must continue to exist. A popup-only composition fixture makes this criterion executable without leaving an unresolved `Topbar` type reference in `shell.qml`.

## Current architecture

`Topbar.qml` owns system behavior for several unrelated domains:

- one composite three-second poll for CPU, memory, disk, volume, network connectivity, battery, and power profile;
- a separate `wpctl` volume probe, a `pw-mon` subscription, and a debounce timer;
- a long-running `playerctl --follow` metadata adapter;
- the Cava process and output parser;
- Niri workspace and focused-window polls plus an event-stream listener;
- volume, media, power-profile, Niri, and application-launch actions.

Popups add more embedded adapters:

- `MediaPopup.qml` polls position and playback settings and constructs player and audio commands;
- `BatteryPopup.qml` polls UPower and stasis, reads and writes the charge threshold, and constructs power actions;
- `SystemPopup.qml` polls host metadata and constructs session commands;
- `WifiPopup.qml` polls and parses NetworkManager state and constructs connection commands;
- `BluetoothPopup.qml` polls and parses BlueZ state and constructs device commands.

This produces duplicated adapters and invalid ownership. In particular, deleting Topbar removes audio, media, power, system metrics, Cava, and Niri behavior used elsewhere.

`NotifService.qml` is the existing positive example: one nonvisual module owns the notification backend, exposes shared state and actions, and is consumed by multiple views. `InfoPopup.qml` is also correctly presentation-owned. Its animation, focus, Escape, and mapping timers remain in the view layer.

## Quickshell capability baseline

The installed Quickshell version is 0.3.0. This version provides native typed integrations for PipeWire, MPRIS, UPower, power profiles, NetworkManager, and Bluetooth. It also tracks ordinary `Process` children and terminates them when the shell exits or reloads.

Native integrations are preferred when they preserve current semantics. Niri, Cava, `/proc`, stasis, the charge threshold, and host/session actions continue to use owned adapters where Quickshell has no equivalent interface.

## Considered approaches

### Explicit shell-owned domain modules

`shell.qml` creates one instance of each domain module and passes typed references to views. This makes dependencies explicit and gives the shell one place to coordinate demand-driven lifecycles. Deleting Topbar leaves every module and popup intact. Test backend injection is a separate construction seam inside each service where deterministic backend tests are valuable.

### Singleton per domain

Each domain uses `pragma Singleton`, following `NotifService.qml`. This minimizes wiring but makes dependencies implicit, complicates isolated tests, and makes consumer-driven lifecycle hints global.

### One global system model

A single singleton exposes every domain. This has the smallest view interface but creates a broad god module whose interface grows with every desktop concern.

## Decision

Use explicit shell-owned domain modules under `home/configs/quickshell/services/`. Each module uses a nonvisual `Scope` root and owns one system domain. Views import the directory and receive required typed module references.

`shell.qml` remains the composition root. It owns:

- construction of one instance per domain module;
- desktop-profile theme loading through the existing `select-quickshell-theme` contract;
- popup coordination and popup visibility;
- demand hints such as detailed media monitoring, Cava requests, and Wi-Fi scanning;
- wiring notification count directly from `NotifService`.

It does not parse system output, poll system state, or construct domain commands.

## Module ownership and interfaces

Interfaces expose typed scalar state, typed actions, and normalized role models for repeated domain objects. They do not expose raw native backend objects. Formatting that depends on visual context stays in views. Subprocess construction, parsing, debounce, retry, and cleanup stay inside the owning module.

Views use nominally typed service references. Tests do not replace those references with unrelated fake objects. Where backend isolation is needed, a real service instance receives a replaceable internal backend object, or delegates parsing and state reduction to a backend-free helper. Production construction keeps those seams private to `shell.qml` and test fixtures.

### AudioService

Owns the current PipeWire default sink through `Pipewire.defaultAudioSink` and `PwObjectTracker`.

State:

- `readonly property bool available`
- `readonly property int volumePercent`
- `readonly property bool muted`

Actions:

- `function setVolume(percent: int): void`
- `function adjustVolume(direction: int): void`
- `function toggleMute(): void`
- `function openMixer(): void`

Volume remains clamped to 0 through 100 percent. Native PipeWire reactivity replaces the composite volume field, `wpctl` probe, `pw-mon` subscription, and volume debounce.

`available` requires PipeWire readiness, a non-null default sink with audio data, and a bound, ready sink. `PwObjectTracker.objects` tracks replacement of the default sink. The current two-percent wheel step remains unchanged. A transient null sink preserves the last valid numeric value while marking the service unavailable.

### MediaService

Owns active-player selection, metadata, playback state, position, capabilities, shuffle, loop state, player volume, and transport actions.

Dependencies:

- `required property AudioService audioService`, used for the existing system-sink fallback when a player has no writable volume.

State:

- `readonly property bool available`
- `readonly property string status`
- `readonly property bool playing`
- `readonly property string title`
- `readonly property string artist`
- `readonly property string album`
- `readonly property string artUrl`
- `readonly property real positionSeconds`
- `readonly property real lengthSeconds`
- `readonly property bool shuffleEnabled`
- `readonly property string loopMode`
- `readonly property real effectiveVolume`
- `readonly property bool volumeIsPlayer`
- `readonly property bool canSeek`
- `readonly property bool canTogglePlaying`
- `readonly property bool canGoNext`
- `readonly property bool canGoPrevious`
- `readonly property bool canShuffle`
- `readonly property bool canLoop`
- `readonly property bool canSetPlayerVolume`

Actions:

- `function togglePlaying(): void`
- `function next(): void`
- `function previous(): void`
- `function seek(seconds: real): void`
- `function toggleShuffle(): void`
- `function cycleLoop(): void`
- `function setEffectiveVolume(volume: real): void`

The migration must preserve current `playerctl` selection semantics. The slice first places the existing adapter behind `MediaService`. A native MPRIS backend replaces it only after player-selection parity is demonstrated for one player, multiple players, paused players, and player disappearance. If parity cannot be proven, retaining one playerctl adapter inside the deep module is an acceptable intentional deferment.

Detailed position updates are demand-driven. `shell.qml` sets `property bool detailedMonitoring` from `mediaPopup.shown`, not `active`, `mapped`, or `warming`. The service owns the timer. With native MPRIS it triggers the selected player's `positionChanged()` signal rather than maintaining a competing optimistic clock.

### CavaService

Owns Cava command construction, configuration path, output parsing, restart policy, and cleanup.

Inputs:

- `property bool playing`
- `property bool requested`

Output:

- `readonly property list<int> values`

The process runs only while media is playing and at least one live consumer requests visualization. Shell computes the request from an instantiated, visible media bar consumer or `mediaPopup.active`. Retained `showMedia` configuration alone cannot keep Cava alive after the Topbar instance is removed. Both views consume the same values.

### NiriService

Owns workspace snapshots, focused-window state, Niri event parsing, recovery reconciliation, and Niri actions.

State:

- `readonly property int activeWorkspaceId`
- `readonly property ListModel workspaces`, a normalized ordered model with integer `id`, boolean `occupied`, boolean `active`, and boolean `urgent` roles
- `readonly property string focusedTitle`
- `readonly property string focusedAppId`
- `readonly property bool streamHealthy`
- `readonly property string lastError`

Actions:

- `function focusWorkspace(id: int): void`
- `function focusAdjacent(direction: int): void`
- `function quitSession(): void`

The event stream becomes the primary update source. Initial snapshots populate state. A low-frequency reconciliation poll repairs missed events, replacing the current one-second and 1.5-second continuous polls. An unexpected stream exit schedules a bounded retry and never starts a second concurrent stream.

### PowerService

Owns battery state, power-profile state, charge-threshold behavior, and stasis idle-inhibit behavior.

Native UPower and `PowerProfiles` provide reactive charge, state, time remaining, rate, health, and current profile. The module retains owned adapters for the machine-specific charge threshold and stasis manual-pause state.

State:

- `readonly property bool available`
- `readonly property int chargePercent`
- `readonly property string state`, one of `unknown`, `charging`, `discharging`, `full`, `pending-charge`, or `pending-discharge`
- `readonly property real secondsRemaining`
- `readonly property real drawWatts`
- `readonly property int healthPercent`
- `readonly property string profile`, one of `power-saver`, `balanced`, `performance`, or `unknown`
- `readonly property int chargeLimit`
- `readonly property bool thresholdWritable`
- `readonly property bool idleInhibited`
- `readonly property bool busy`
- `readonly property string lastError`, limited to owned threshold and stasis adapters

Actions:

- `function setProfile(profile: string): void`
- `function cycleProfile(direction: int): void`
- `function setChargeLimit(percent: int): void`
- `function toggleChargeLimit(): void`
- `function toggleIdleInhibit(): void`

Quickshell 0.3 does not expose a readiness property for `PowerProfiles`, and some native write failures are log-only. The module does not fabricate actionable errors for those calls. Daemon disappearance may require a shell reload; device churn remains reactive.

### SystemService

Owns CPU, memory, disk, hostname, kernel, uptime, NixOS generation, and host actions.

State:

- `readonly property bool available`
- `readonly property int cpuPercent`
- `readonly property real ramUsedGiB`
- `readonly property int ramPercent`
- `readonly property int diskPercent`
- `readonly property string hostName`
- `readonly property string kernel`
- `readonly property string uptime`
- `readonly property string nixGeneration`
- `readonly property string lastError`

Dynamic metrics use one coordinated polling lifecycle. Static host metadata is refreshed on construction and when explicitly invalidated, not every dynamic interval. The module exposes numeric percentages and raw values; views own display formatting.

Actions:

- `function lock(): void`
- `function suspend(): void`
- `function reboot(): void`
- `function powerOff(): void`

Niri session logout remains a `NiriService` action.

### NetworkService

Owns Wi-Fi enabled state, active network, visible networks, scan lifecycle, connection state, and network actions through Quickshell 0.3's NetworkManager integration. It replaces the popup poll and the connectivity field in Topbar's composite poll.

State:

- `readonly property bool available`
- `readonly property bool wifiEnabled`
- `readonly property bool connected`, general NetworkManager connectivity for the bar, including non-Wi-Fi connectivity
- `readonly property string activeSsid`
- `readonly property int activeSignal`
- `readonly property string activeSecurity`
- `readonly property ListModel networks`, a normalized model with string `ssid`, integer `signal`, string `security`, and boolean `secure`, `known`, `active`, and `busy` roles
- `property bool scanningRequested`

Actions:

- `function setWifiEnabled(enabled: bool): void`
- `function connectKnown(ssid: string): void`
- `function connectInteractive(ssid: string): void`
- `function openSettings(): void`

`scanningRequested` follows `wifiPopup.shown`. The service selects a deterministic Wi-Fi device, deduplicates SSIDs by strongest access point, sorts by signal, and exposes at most the current eight entries. Known networks use the native connect path. Unknown or no-secrets networks retain detached `kitty -e nmtui-connect`. The bar's existing settings action remains a typed `openSettings()` call.

Quickshell 0.3 selects its NetworkManager backend at singleton construction and does not recover it automatically if the daemon was absent. The service distinguishes device churn from backend absence and documents shell reload as the recovery path rather than promising automatic daemon recovery.

### BluetoothService

Owns adapter state, paired devices, connection state, and connect, disconnect, enable, and manager actions through Quickshell 0.3's Bluetooth integration. It replaces the popup's BlueZ polling and command construction.

State:

- `readonly property bool available`
- `readonly property bool enabled`
- `readonly property int connectedCount`
- `readonly property ListModel devices`, a normalized paired-only model with string `id`, string `name`, boolean `connected`, and boolean `busy` roles, sorted connected-first then by name. `id` is the stable BlueZ device address when native, with an internal id-to-object map for actions.

Actions:

- `function setEnabled(enabled: bool): void`
- `function toggleDevice(id: string): void`
- `function openManager(): void`

BlueZ connect and disconnect failures are logged internally by Quickshell 0.3 and do not expose a failure signal. The interface therefore does not promise an actionable native `lastError`. If BlueZ is absent at singleton construction, shell reload is the supported recovery path.

## Presentation ownership

The following stay in views:

- colors, icons, labels, truncation, and display formatting;
- hover, press, wheel, drag, and seeking gesture state;
- popup mapping, focus, animation, Escape handling, and click-catching;
- calendar view-month selection and visible-date refresh;
- notification toast expiry and notification grouping;
- bar module visibility and layout;
- popup busy indicators derived from service state.

Views contain no `Process`, domain parser, debounce timer, polling timer, or domain command construction after their slice is migrated.

## Data flow

1. A native integration or owned process emits a state change.
2. The owning module validates and normalizes it into typed state.
3. QML bindings propagate the state to every consumer of the same module instance.
4. A view gesture calls a typed action on that module.
5. The module validates the request, performs the native write or launches the owned command, and updates through the normal state source.

Views do not optimistically maintain independent copies of domain state except for transient gesture state such as an in-progress seek drag.

## Process lifecycle

- A module never starts a second copy of an already-running process.
- Long-running adapters are ordinary tracked `Process` children and prefer direct commands or an `exec` wrapper.
- Quickshell termination covers the direct process, not an arbitrary descendant tree. Defensive parent-death handling remains until each long-running adapter demonstrates cleanup under full exit and the real profile-switch termination path.
- Cava runs only on demand.
- Niri's stream is single-instance and uses bounded retry after unexpected exit.
- Poll processes skip a trigger while already running.
- Detached processes are reserved for intentionally independent applications such as the mixer or terminal UI.
- Service destruction, shell reload, and full shell exit must leave no owned child processes.

## Error handling

- Native objects may be temporarily unavailable during device changes. Backend absence at singleton construction follows the domain-specific recovery contract above.
- A transient unavailable state does not fabricate values or clear unrelated valid fields.
- Parser failure preserves the last complete valid snapshot.
- Commands expose busy and last-error state where a view needs feedback.
- Errors available through the backend are logged on state transitions rather than on every poll.
- Failed streams use bounded retry and do not spin.
- Unsupported native capabilities disable the corresponding action while preserving fallback labels.
- Device churn is handled reactively where the native integration supports it. Daemon loss is not claimed to recover automatically when Quickshell 0.3 initializes that backend only once.

## Testing

Add a focused two-layer `just quickshell-test` recipe.

The first layer uses `qmltestrunner` only for pure parser modules and backend-free QtQuick reducers. It does not claim to reproduce Quickshell shell generations or reload behavior.

The second layer launches isolated nonvisual fixtures with `quickshell -p`. It covers typed service construction, action validation, shared state propagation, process non-overlap, native integrations, shell-generation reload behavior, and descendant process cleanup. Fake executables injected through `PATH` record commands, parent IDs, descendant IDs, and lifecycle events without mutating the live desktop.

Behavioral coverage includes:

- parser fixtures for Niri, Cava, metrics, and any retained command adapter, including chunked input, partial records, CRLF, empty output, malformed data, missing fields, extra fields, and nonzero exits;
- volume clamping and mute propagation;
- media player selection, disappearance, capabilities, and monitoring lifecycle;
- power-profile mapping and unavailable battery state;
- state propagation to two consumers sharing one module instance, including identity, one update per backend event, and one backend action per gesture;
- process non-overlap and bounded restart behavior;
- process cleanup after service destruction, shell reload, and the profile-switch termination path;
- structural checks that reject `Process`, domain commands, and detached execution in migrated views;
- structural checks that assert one adapter per migrated domain;
- popup lifecycle checks that keep `shown`, `active`, `mapped`, and `warming` semantics distinct;
- regression checks that leave theme loading and all `InfoPopup` animation, frozen-height, focus, Escape, and outside-click behavior unchanged.

Runtime smoke tests record command signatures and process ancestry before and after each slice. Broad process-name counts are insufficient because one shell adapter may have wrapper and descendant processes. Final verification covers the live bar and every migrated popup.

## Migration sequence

Each vertical slice includes tests, migration, duplicate-adapter deletion, focused verification, and live smoke testing when practical. Ownership moves and native backend substitutions use separate logical commits so either can be reverted independently. No commit may contain a temporary dual-adapter state.

1. Add the two-layer harness, fixtures, structural checker, and baseline process manifest.
2. Move all system-sink ownership behind `AudioService` using the existing `wpctl` and `pw-mon` backend. Wire Topbar, VolumePopup, and MediaPopup's sink fallback to the same instance and delete every external QML sink adapter.
3. Replace AudioService's backend with native PipeWire without changing its public interface.
4. Move media ownership behind `MediaService` while retaining playerctl.
5. Replace the media backend with native MPRIS only after player-selection parity is proven.
6. Migrate Cava.
7. Migrate power and battery behavior.
8. Migrate system metrics, metadata, and host actions.
9. Migrate Niri workspaces, focused-window state, and actions.
10. Migrate network behavior.
11. Migrate Bluetooth behavior.
12. Remove final obsolete Topbar state, bind notification count directly to `NotifService`, and run the popup-only deletion-test audit.

Audio is the first behavioral slice because it has overlapping adapters, crosses Topbar, VolumePopup, and MediaPopup, and has a native reactive replacement with a small typed interface. The harness spike precedes it.

## Verification

For every slice:

- run focused behavioral tests;
- run `just qml-lint`;
- confirm no duplicate command signatures or adapter process trees remain for that domain;
- smoke-test the relevant bar module and popup.

Before final handoff:

- run all focused service tests;
- run `just qml-lint`;
- run `just eval laptop`;
- run `just check`;
- run `just build laptop`;
- run `just switch` only if no competing switch holds `/run/nixos-auto-update.lock`;
- smoke-test the live bar and every migrated popup;
- audit process counts and orphan cleanup;
- obtain an independent implementation review from a different model or model family.

## Acceptance criteria

- The popup-only composition fixture loads and exercises shared services and popups without importing or referencing Topbar.
- Removing the Topbar instance and its bindings, then deleting the file, removes only bar presentation.
- Migrated popups continue to work without state or action paths through Topbar.
- Each migrated domain has one owning module and one adapter lifecycle.
- Views contain only presentation state and typed action invocation.
- Desktop profile and variant propagation still use the existing manifest and runtime-theme contract.
- `InfoPopup.qml` behavior and popup conventions remain unchanged.
- Appearance, interactions, keybindings, and runtime semantics remain unchanged.
- Focused tests and all required repository verification pass.
