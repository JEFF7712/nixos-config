pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

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

    function toggle(name: string, screenName: string): void {
        const same = open === name && openScreen === screenName;
        openScreen = screenName;
        open = same ? "" : name;
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
    Services.SystemService {
        id: system
        detailedMonitoring: machine.open === "system"
    }
}
