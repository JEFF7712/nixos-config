import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: root

    // Popup-only deletion fixture: same domain services and migrated popups,
    // no bar presentation root and no notification history UI. Native
    // singleton actions are not exercised here — only reads plus
    // command-backed recorders.

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""

    Services.AudioService {
        id: audioService
    }

    Services.MediaService {
        id: mediaService
        audioService: audioService
        detailedMonitoring: false
    }

    Services.CavaService {
        id: cavaService
        playing: false
        requested: mediaPopup.active
    }

    Services.PowerService {
        id: powerService
        detailedMonitoring: false
    }

    Services.SystemService {
        id: systemService
        detailedMonitoring: false
    }

    Services.NiriService {
        id: niriService
    }

    Services.NetworkService {
        id: networkService
        scanningRequested: false
    }

    Services.BluetoothService {
        id: bluetoothService
        detailedMonitoring: false
    }

    VolumePopup {
        id: volumePopup
        audioService: audioService
    }

    WifiPopup {
        id: wifiPopup
        networkService: networkService
    }

    BluetoothPopup {
        id: bluetoothPopup
        bluetoothService: bluetoothService
    }

    BatteryPopup {
        id: batteryPopup
        powerService: powerService
    }

    SystemPopup {
        id: systemPopup
        systemService: systemService
        niriService: niriService
    }

    MediaPopup {
        id: mediaPopup
        mediaService: mediaService
        cavaService: cavaService
    }

    function finish() {
        const audioOk = typeof volumePopup.audioService.volumePercent === "number" && typeof volumePopup.audioService.muted === "boolean";
        const networkOk = typeof wifiPopup.networkService.available === "boolean" && typeof wifiPopup.networkService.connected === "boolean";
        const bluetoothOk = typeof bluetoothPopup.bluetoothService.available === "boolean" && typeof bluetoothPopup.bluetoothService.enabled === "boolean";
        const powerOk = typeof batteryPopup.powerService.available === "boolean" && typeof batteryPopup.powerService.chargePercent === "number";
        const systemOk = typeof systemPopup.systemService.available === "boolean" && typeof systemPopup.systemService.cpuPercent === "number" && typeof systemPopup.niriService.activeWorkspaceId === "number";
        const mediaOk = typeof mediaPopup.mediaService.status === "string" && mediaPopup.cavaService.values !== undefined;

        // Command-backed recorders only — never mutate native radio/power/BT/session.
        systemPopup.systemService.lock();
        bluetoothPopup.bluetoothService.openManager();

        const passed = audioOk && networkOk && bluetoothOk && powerOk && systemOk && mediaOk;
        resultFile.setText(JSON.stringify({
            passed: passed,
            diagnostics: {
                audioOk: audioOk,
                networkOk: networkOk,
                bluetoothOk: bluetoothOk,
                powerOk: powerOk,
                systemOk: systemOk,
                mediaOk: mediaOk,
                volumePercent: volumePopup.audioService.volumePercent,
                networkConnected: wifiPopup.networkService.connected,
                bluetoothAvailable: bluetoothPopup.bluetoothService.available,
                chargePercent: batteryPopup.powerService.chargePercent,
                cpuPercent: systemPopup.systemService.cpuPercent,
                mediaStatus: mediaPopup.mediaService.status
            }
        }) + "\n");
        Qt.quit();
    }

    FileView {
        id: readyFile
        path: root.stateDir + "/ready"
        blockWrites: true
    }

    FileView {
        id: resultFile
        path: root.stateDir + "/result.json"
        blockWrites: true
    }

    Component.onCompleted: {
        readyFile.setText("ready\n");
        settleTimer.start();
    }

    Timer {
        id: settleTimer
        interval: 1200
        repeat: false
        onTriggered: root.finish()
    }

    Timer {
        interval: 8000
        running: true
        repeat: false
        onTriggered: {
            resultFile.setText(JSON.stringify({
                passed: false,
                diagnostics: {
                    error: "popup-only composition timed out"
                }
            }) + "\n");
            Qt.quit();
        }
    }
}
