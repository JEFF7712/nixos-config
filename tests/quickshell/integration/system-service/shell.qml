import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: root

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""
    property int phase: 0
    property double phaseStarted: Date.now()
    property QtObject consumerOne: QtObject {
        property var service: systemService
    }
    property QtObject consumerTwo: QtObject {
        property var service: systemService
    }

    Services.SystemService {
        id: systemService
    }

    function elapsed(): double {
        return Date.now() - root.phaseStarted;
    }
    function advance(): void {
        root.phase++;
        root.phaseStarted = Date.now();
    }
    function validTypes(): bool {
        return typeof systemService.available === "boolean" && Number.isInteger(systemService.cpuPercent) && typeof systemService.ramUsedGiB === "number" && Number.isInteger(systemService.ramPercent) && Number.isInteger(systemService.diskPercent) && typeof systemService.hostName === "string" && typeof systemService.kernel === "string" && typeof systemService.uptime === "string" && typeof systemService.nixGeneration === "string" && typeof systemService.lastError === "string";
    }
    function validRange(): bool {
        return systemService.cpuPercent >= 0 && systemService.cpuPercent <= 100 && systemService.ramUsedGiB >= 0 && systemService.ramPercent >= 0 && systemService.ramPercent <= 100 && systemService.diskPercent >= 0 && systemService.diskPercent <= 100;
    }
    function diagnostics(): var {
        return {
            available: systemService.available,
            cpuPercent: systemService.cpuPercent,
            ramUsedGiB: systemService.ramUsedGiB,
            ramPercent: systemService.ramPercent,
            diskPercent: systemService.diskPercent,
            hostName: systemService.hostName,
            kernel: systemService.kernel,
            uptime: systemService.uptime,
            nixGeneration: systemService.nixGeneration,
            lastError: systemService.lastError
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
            sharedIdentity: root.consumerOne.service === root.consumerTwo.service,
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
        id: actionsFile
        path: root.stateDir + "/actions.log"
        blockLoading: true
    }

    Component.onCompleted: readyFile.setText("ready\n")

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (root.elapsed() > 15000)
                return root.fail("phase timeout");

            if (root.phase === 0) {
                if (systemService.available && systemService.hostName !== "") {
                    if (!root.validTypes() || !root.validRange())
                        return root.fail("system service public contract is invalid");
                    root.advance();
                }
            } else if (root.phase === 1) {
                systemService.lock();
                root.advance();
            } else if (root.phase === 2) {
                systemService.suspend();
                root.advance();
            } else if (root.phase === 3) {
                systemService.reboot();
                root.advance();
            } else if (root.phase === 4) {
                systemService.powerOff();
                root.advance();
            } else if (root.phase === 5 && root.elapsed() >= 200) {
                actionsFile.reload();
                actionsFile.waitForJob();
                const actions = actionsFile.text().trim();
                if (actions !== "lock\nsystemctl suspend\nsystemctl reboot\nsystemctl poweroff")
                    return root.fail("action log mismatch: " + actions);
                root.finish();
            }
        }
    }
}
