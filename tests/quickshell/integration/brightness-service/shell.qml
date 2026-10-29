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

    Services.BrightnessService {
        id: brightnessService
    }

    function elapsed(): double {
        return Date.now() - root.phaseStarted;
    }
    function advance(): void {
        root.phase++;
        root.phaseStarted = Date.now();
    }
    function setLines(): var {
        setsFile.reload();
        setsFile.waitForJob();
        return setsFile.text().split("\n").filter(line => line.trim() !== "");
    }
    function optimisticPercent(id: string): int {
        for (let i = 0; i < brightnessService.displays.count; i++) {
            const entry = brightnessService.displays.get(i);
            if (entry.id === id)
                return entry.percent;
        }
        return -1;
    }
    function diagnostics(): var {
        return {
            available: brightnessService.available,
            displayCount: brightnessService.displays.count,
            averagePercent: brightnessService.averagePercent,
            lastError: brightnessService.lastError,
            sets: root.setLines()
        };
    }
    function fail(message): void {
        resultFile.setText(JSON.stringify({
            passed: false,
            phase: root.phase,
            error: message,
            diagnostics: root.diagnostics()
        }) + "\n");
        Qt.quit();
    }
    function finish(): void {
        resultFile.setText(JSON.stringify({
            passed: true,
            busyObserved: root.busyObserved,
            diagnostics: root.diagnostics()
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
        id: setsFile
        path: root.stateDir + "/sets.log"
        blockLoading: true
    }

    Component.onCompleted: readyFile.setText("ready\n")

    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (root.elapsed() > 30000)
                return root.fail("phase timeout");
            if (brightnessService.busy)
                root.busyObserved = true;

            if (root.phase === 0 && !brightnessService.busy) {
                if (!brightnessService.available || brightnessService.displays.count !== 3)
                    return;
                if (brightnessService.averagePercent !== 50)
                    return root.fail("initial average mismatch");
                brightnessService.setBrightness("ddc-1", 42);
                brightnessService.setBrightness("ddc-1", 42);
                root.advance();
            } else if (root.phase === 1 && !brightnessService.busy) {
                const lines = root.setLines();
                if (lines.length !== 1 || lines[0] !== "ddc-1 42")
                    return;
                brightnessService.adjustAll(1);
                root.advance();
            } else if (root.phase === 2 && !brightnessService.busy) {
                const lines = root.setLines();
                if (lines.length !== 4)
                    return;
                if (lines[0] !== "ddc-1 42" || lines[1] !== "internal 40" || lines[2] !== "ddc-1 47" || lines[3] !== "ddc-2 70")
                    return root.fail("set sequence mismatch: " + JSON.stringify(lines));
                if (root.optimisticPercent("ddc-1") !== 47 || root.optimisticPercent("internal") !== 40 || root.optimisticPercent("ddc-2") !== 70)
                    return root.fail("model did not apply optimistic values");
                if (!root.busyObserved)
                    return root.fail("busy was never observable");
                root.finish();
            }
        }
    }
}
