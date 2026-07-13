import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: root

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""
    property string destructionMode: Quickshell.env("QS_POWER_DESTRUCTION_MODE") || ""
    property int phase: 0
    property double phaseStarted: Date.now()
    property bool busyObserved: false
    property int probeBaseline: 0
    property QtObject consumerOne: QtObject {
        property var service: powerService
    }
    property QtObject consumerTwo: QtObject {
        property var service: powerService
    }

    Services.PowerService {
        id: powerService
    }

    function elapsed(): double {
        return Date.now() - root.phaseStarted;
    }
    function advance(): void {
        root.phase++;
        root.phaseStarted = Date.now();
    }
    function scalars(): var {
        return {
            chargeLimit: powerService.chargeLimit,
            thresholdWritable: powerService.thresholdWritable,
            idleInhibited: powerService.idleInhibited,
            lastError: powerService.lastError
        };
    }
    function probeCount(): int {
        callsFile.reload();
        callsFile.waitForJob();
        return callsFile.text().split("\n").filter(line => line.trim() === "stasis info").length;
    }
    function fail(message): void {
        resultFile.setText(JSON.stringify({
            passed: false,
            phase: root.phase,
            error: message,
            diagnostics: root.scalars()
        }) + "\n");
        Qt.quit();
    }
    function finish(): void {
        resultFile.setText(JSON.stringify({
            passed: true,
            sharedIdentity: root.consumerOne.service === root.consumerTwo.service,
            busyObserved: root.busyObserved,
            diagnostics: root.scalars()
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
        id: callsFile
        path: root.stateDir + "/calls.log"
        blockLoading: true
    }

    Component.onCompleted: readyFile.setText("ready\n")

    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (root.destructionMode === "probe")
                return;
            if (root.destructionMode === "action") {
                if (root.phase === 0) {
                    root.phase = 1;
                    powerService.toggleIdleInhibit();
                }
                return;
            }
            if (root.elapsed() > 35000)
                root.fail("phase timeout");
            if (powerService.busy)
                root.busyObserved = true;

            if (root.phase === 0 && !powerService.busy) {
                if (powerService.chargeLimit !== 80 || !powerService.thresholdWritable || powerService.idleInhibited)
                    return root.fail("initial adapter state mismatch");
                root.probeBaseline = root.probeCount();
                root.advance();
            } else if (root.phase === 1 && root.elapsed() >= 5500) {
                if (root.probeCount() !== root.probeBaseline)
                    return root.fail("hidden cadence polled before 30 seconds");
                powerService.detailedMonitoring = true;
                root.advance();
            } else if (root.phase === 2 && root.probeCount() === root.probeBaseline + 1 && !powerService.busy) {
                root.probeBaseline = root.probeCount();
                root.advance();
            } else if (root.phase === 3 && root.elapsed() >= 5200) {
                if (root.probeCount() !== root.probeBaseline + 1)
                    return root.fail("shown cadence did not poll exactly once after five seconds");
                powerService.detailedMonitoring = false;
                root.probeBaseline = root.probeCount();
                root.advance();
            } else if (root.phase === 4 && root.elapsed() >= 5500) {
                if (root.probeCount() !== root.probeBaseline)
                    return root.fail("hidden cadence did not resume at 30 seconds");
                root.probeBaseline = root.probeCount();
                powerService.setChargeLimit(75);
                root.advance();
            } else if (root.phase === 5 && powerService.chargeLimit === 75 && !powerService.busy) {
                powerService.toggleChargeLimit();
                root.advance();
            } else if (root.phase === 6 && powerService.chargeLimit === 100 && !powerService.busy) {
                powerService.toggleIdleInhibit();
                root.advance();
            } else if (root.phase === 7 && powerService.idleInhibited && !powerService.busy) {
                root.probeBaseline = root.probeCount();
                powerService.toggleIdleInhibit();
                powerService.toggleIdleInhibit();
                root.advance();
            } else if (root.phase === 8 && powerService.idleInhibited && !powerService.busy && root.probeCount() === root.probeBaseline + 1) {
                if (!root.busyObserved)
                    return root.fail("busy was never observable");
                finish();
            }
        }
    }
}
