import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: root

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""
    property int phase: 0
    property double phaseStarted: Date.now()
    property bool busyObserved: false

    Services.BluetoothService {
        id: bluetoothService
        detailedMonitoring: true
    }

    function elapsed(): double {
        return Date.now() - root.phaseStarted;
    }
    function advance(): void {
        root.phase++;
        root.phaseStarted = Date.now();
    }
    function fail(message): void {
        resultFile.setText(JSON.stringify({
            passed: false,
            phase: root.phase,
            error: message
        }) + "\n");
        Qt.quit();
    }
    function finish(): void {
        resultFile.setText(JSON.stringify({
            passed: true,
            busyObserved: root.busyObserved,
            diagnostics: {
                available: bluetoothService.available,
                enabled: bluetoothService.enabled,
                connectedCount: bluetoothService.connectedCount,
                deviceCount: bluetoothService.devices.count
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
        tick.start();
    }

    Timer {
        id: tick
        interval: 50
        running: false
        repeat: true
        onTriggered: {
            if (root.elapsed() > 20000)
                return root.fail("phase timeout");
            if (root.phase === 0) {
                if (bluetoothService.available && bluetoothService.enabled && bluetoothService.devices.count === 2) {
                    bluetoothService.setEnabled(false);
                    root.advance();
                }
            } else if (root.phase === 1 && root.elapsed() >= 300) {
                if (!bluetoothService.enabled) {
                    bluetoothService.setEnabled(true);
                    root.advance();
                }
            } else if (root.phase === 2 && root.elapsed() >= 300) {
                if (bluetoothService.enabled) {
                    const id = bluetoothService.devices.get(0).id;
                    bluetoothService.toggleDevice(id);
                    root.busyObserved = true;
                    root.advance();
                }
            } else if (root.phase === 3 && root.elapsed() >= 400) {
                bluetoothService.openManager();
                root.finish();
            }
        }
    }

    Timer {
        interval: 25000
        running: true
        repeat: false
        onTriggered: root.fail("bluetooth fixture timed out")
    }
}
