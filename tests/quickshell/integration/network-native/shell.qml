import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: root

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""

    Services.NetworkService {
        id: networkService
        scanningRequested: false
    }

    function finish() {
        const available = networkService.available;
        const validTypes = typeof networkService.available === "boolean" && typeof networkService.wifiEnabled === "boolean" && typeof networkService.connected === "boolean" && typeof networkService.activeSsid === "string" && typeof networkService.activeSignal === "number" && typeof networkService.activeSecurity === "string" && networkService.networks !== null && networkService.networks !== undefined && typeof networkService.networks.count === "number";
        const validRange = validTypes && Number.isInteger(networkService.activeSignal) && networkService.activeSignal >= 0 && networkService.activeSignal <= 100 && networkService.networks.count >= 0 && networkService.networks.count <= 8;
        networkService.openSettings();
        resultFile.setText(JSON.stringify({
            passed: validTypes && validRange,
            diagnostics: {
                available: available,
                skipped: !available,
                wifiEnabled: networkService.wifiEnabled,
                connected: networkService.connected,
                activeSsid: networkService.activeSsid,
                activeSignal: networkService.activeSignal,
                activeSecurity: networkService.activeSecurity,
                networkCount: networkService.networks.count
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
        id: kittyLog
        path: root.stateDir + "/kitty-calls.log"
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
                    error: "native network construction timed out"
                }
            }) + "\n");
            Qt.quit();
        }
    }
}
