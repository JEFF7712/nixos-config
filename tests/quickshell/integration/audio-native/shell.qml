import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: root

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""

    Services.AudioService {
        id: audioService
    }

    function finish() {
        const available = audioService.available;
        const validTypes = typeof audioService.available === "boolean" && typeof audioService.volumePercent === "number" && typeof audioService.muted === "boolean";
        const validRange = Number.isInteger(audioService.volumePercent) && audioService.volumePercent >= 0 && audioService.volumePercent <= 100;
        audioService.openMixer();
        resultFile.setText(JSON.stringify({
            passed: validTypes && validRange,
            diagnostics: {
                available: available,
                skipped: !available,
                volumePercent: audioService.volumePercent,
                muted: audioService.muted
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
        interval: 5000
        running: true
        repeat: false
        onTriggered: {
            resultFile.setText(JSON.stringify({
                passed: false,
                diagnostics: {
                    error: "native audio construction timed out"
                }
            }) + "\n");
            Qt.quit();
        }
    }
}
