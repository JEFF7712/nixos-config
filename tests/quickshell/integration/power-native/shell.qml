import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: root

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""

    Services.PowerService {
        id: powerService
    }

    function finish() {
        const available = powerService.available;
        const validStates = ["unknown", "charging", "discharging", "full", "pending-charge", "pending-discharge"];
        const validProfiles = ["power-saver", "balanced", "performance", "unknown"];
        const validTypes = typeof powerService.available === "boolean" && typeof powerService.chargePercent === "number" && typeof powerService.state === "string" && typeof powerService.secondsRemaining === "number" && typeof powerService.drawWatts === "number" && typeof powerService.healthPercent === "number" && typeof powerService.profile === "string" && typeof powerService.chargeLimit === "number" && typeof powerService.thresholdWritable === "boolean" && typeof powerService.idleInhibited === "boolean" && typeof powerService.busy === "boolean" && typeof powerService.lastError === "string";
        const validRange = validTypes && Number.isInteger(powerService.chargePercent) && powerService.chargePercent >= 0 && powerService.chargePercent <= 100 && powerService.secondsRemaining >= 0 && powerService.drawWatts >= 0 && Number.isInteger(powerService.healthPercent) && powerService.healthPercent >= 0 && powerService.healthPercent <= 100 && Number.isInteger(powerService.chargeLimit) && powerService.chargeLimit >= 0 && powerService.chargeLimit <= 100 && validStates.indexOf(powerService.state) !== -1 && validProfiles.indexOf(powerService.profile) !== -1;
        resultFile.setText(JSON.stringify({
            passed: validTypes && validRange,
            diagnostics: {
                available: available,
                skipped: !available,
                state: powerService.state,
                profile: powerService.profile,
                chargePercent: powerService.chargePercent,
                chargeLimit: powerService.chargeLimit,
                thresholdWritable: powerService.thresholdWritable,
                idleInhibited: powerService.idleInhibited,
                busy: powerService.busy
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
                    error: "native power construction timed out"
                }
            }) + "\n");
            Qt.quit();
        }
    }
}
