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
    property var stableState: ({})
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
            available: powerService.available,
            chargePercent: powerService.chargePercent,
            state: powerService.state,
            secondsRemaining: powerService.secondsRemaining,
            drawWatts: powerService.drawWatts,
            healthPercent: powerService.healthPercent,
            profile: powerService.profile,
            chargeLimit: powerService.chargeLimit,
            thresholdWritable: powerService.thresholdWritable,
            idleInhibited: powerService.idleInhibited,
            lastError: powerService.lastError
        };
    }
    function probeCount(): int {
        callsFile.reload();
        callsFile.waitForJob();
        return callsFile.text().split("\n").filter(line => line.trim() === "upower -e").length;
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
        id: malformedFile
        path: root.stateDir + "/malformed-upower"
        blockWrites: true
    }
    FileView {
        id: missingProfileFile
        path: root.stateDir + "/profile-daemon-missing"
        blockWrites: true
    }
    FileView {
        id: slowActionFile
        path: root.stateDir + "/slow-action"
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
                if (powerService.available && root.phase === 0) {
                    root.phase = 1;
                    powerService.setProfile("performance");
                }
                return;
            }
            if (root.elapsed() > 35000)
                root.fail("phase timeout");
            if (powerService.busy)
                root.busyObserved = true;

            if (root.phase === 0 && powerService.available && powerService.profile === "balanced") {
                if (powerService.chargePercent !== 64 || powerService.state !== "discharging" || powerService.secondsRemaining !== 9000 || powerService.healthPercent !== 80 || powerService.chargeLimit !== 80 || !powerService.thresholdWritable || powerService.idleInhibited)
                    return root.fail("initial state mismatch");
                root.stableState = root.scalars();
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
                malformedFile.setText("1\n");
                root.probeBaseline = root.probeCount();
                powerService.setProfile("performance");
                root.advance();
            } else if (root.phase === 5 && root.probeCount() === root.probeBaseline + 1 && powerService.profile === "performance" && !powerService.busy) {
                if (powerService.chargePercent !== root.stableState.chargePercent)
                    return root.fail("malformed probe replaced last valid battery state");
                malformedFile.setText("");
                powerService.cycleProfile(1);
                root.advance();
            } else if (root.phase === 6 && powerService.profile === "power-saver" && !powerService.busy) {
                powerService.cycleProfile(-1);
                root.advance();
            } else if (root.phase === 7 && powerService.profile === "performance" && !powerService.busy) {
                powerService.setChargeLimit(75);
                root.advance();
            } else if (root.phase === 8 && powerService.chargeLimit === 75 && !powerService.busy) {
                powerService.toggleChargeLimit();
                root.advance();
            } else if (root.phase === 9 && powerService.chargeLimit === 100 && !powerService.busy) {
                powerService.toggleIdleInhibit();
                root.advance();
            } else if (root.phase === 10 && powerService.idleInhibited && !powerService.busy) {
                missingProfileFile.setText("1\n");
                powerService.toggleIdleInhibit();
                root.advance();
            } else if (root.phase === 11 && !powerService.idleInhibited && powerService.profile === "unknown" && !powerService.busy) {
                missingProfileFile.setText("");
                slowActionFile.setText("1\n");
                root.probeBaseline = root.probeCount();
                powerService.setProfile("power-saver");
                powerService.setProfile("performance");
                powerService.setProfile("balanced");
                root.advance();
            } else if (root.phase === 12 && powerService.profile === "balanced" && !powerService.busy && root.probeCount() >= root.probeBaseline + 1) {
                if (!root.busyObserved)
                    return root.fail("busy was never observable");
                if (root.probeCount() !== root.probeBaseline + 1)
                    return root.fail("rapid actions did not coalesce to one reconciliation");
                finish();
            }
        }
    }
}
