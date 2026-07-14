import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: root

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""

    Services.BluetoothService {
        id: bluetoothService
        detailedMonitoring: false
    }

    function finish() {
        const available = bluetoothService.available;
        const validTypes = typeof bluetoothService.available === "boolean" && typeof bluetoothService.enabled === "boolean" && typeof bluetoothService.connectedCount === "number" && bluetoothService.devices !== null && bluetoothService.devices !== undefined && typeof bluetoothService.devices.count === "number";
        const validRange = validTypes && Number.isInteger(bluetoothService.connectedCount) && bluetoothService.connectedCount >= 0 && bluetoothService.devices.count >= 0 && bluetoothService.connectedCount <= bluetoothService.devices.count;
        bluetoothService.openManager();
        resultFile.setText(JSON.stringify({
            passed: validTypes && validRange,
            diagnostics: {
                available: available,
                skipped: !available,
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

    FileView {
        id: bluemanLog
        path: root.stateDir + "/blueman-calls.log"
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
        interval: 5000
        running: true
        repeat: false
        onTriggered: {
            resultFile.setText(JSON.stringify({
                passed: false,
                diagnostics: {
                    error: "native bluetooth construction timed out"
                }
            }) + "\n");
            Qt.quit();
        }
    }
}
