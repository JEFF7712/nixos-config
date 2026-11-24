pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services
import "hass" as Hass

// The repo bar's system services (home/configs/quickshell/services, linked in),
// so folio's words read the same state as the other profiles' bar.
Singleton {
    id: machine
    property string open: ""
    property string openScreen: ""
    readonly property alias power: power
    readonly property alias brightness: brightness
    readonly property alias network: network
    readonly property alias bluetooth: bluetooth
    readonly property alias system: system
    readonly property alias home: home

    // Switching panels closes the open one first: a grabbing popup can't map
    // while its sibling still holds the grab, so a direct swap flickers.
    property string pending: ""
    property string pendingScreen: ""
    function toggle(name: string, screenName: string): void {
        const same = open === name && openScreen === screenName;
        if (swap.running && pending === name && pendingScreen === screenName) {
            swap.stop();
            pending = "";
            return;
        }
        if (same || open === "") {
            swap.stop();
            pending = "";
            openScreen = screenName;
            open = same ? "" : name;
            return;
        }
        pending = name;
        pendingScreen = screenName;
        open = "";
        swap.restart();
    }
    // Nothing stays open over the lock screen or the launcher.
    property Connections shell: Connections {
        target: ShellState
        function onLockedChanged(): void {
            if (ShellState.locked)
                machine.closeAll();
        }
        function onAskingChanged(): void {
            if (ShellState.asking)
                machine.closeAll();
        }
    }
    function closeAll(): void {
        swap.stop();
        pending = "";
        open = "";
    }
    property Timer swap: Timer {
        interval: 60
        onTriggered: {
            machine.openScreen = machine.pendingScreen;
            machine.open = machine.pending;
            machine.pending = "";
        }
    }

    // Survive the folio shell being stopped mid-command (profile switches).
    function detach(command): void {
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--collect", "--quiet", "--"].concat(command));
    }

    IpcHandler {
        target: "machine"
        function toggle(name: string): void {
            machine.toggle(name, Niri.focusedOutput);
        }
    }

    Services.PowerService {
        id: power
        detailedMonitoring: machine.open === "power"
    }
    Services.BrightnessService {
        id: brightness
        detailedMonitoring: machine.open === "brightness"
    }
    Services.NetworkService {
        id: network
        scanningRequested: machine.open === "network"
    }
    Services.BluetoothService {
        id: bluetooth
        detailedMonitoring: machine.open === "bluetooth"
    }
    Hass.Service {
        id: home
    }
    Services.SystemService {
        id: system
        detailedMonitoring: machine.open === "system"
    }
}
