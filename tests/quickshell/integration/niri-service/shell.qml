import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: root

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""
    property int phase: 0
    property double phaseStarted: Date.now()
    property bool malformedEventIgnored: false
    property bool actionsPassed: false
    property bool retryTimingPassed: false
    property bool exhaustionPassed: false
    property QtObject consumerOne: QtObject {
        property var service: niriService
    }
    property QtObject consumerTwo: QtObject {
        property var service: niriService
    }

    Services.NiriService {
        id: niriService
    }

    function elapsed(): double {
        return Date.now() - root.phaseStarted;
    }
    function advance(): void {
        root.phase++;
        root.phaseStarted = Date.now();
    }
    function workspaceIds(): var {
        const ids = [];
        for (let i = 0; i < niriService.workspaces.count; i++)
            ids.push(niriService.workspaces.get(i).id);
        return ids;
    }
    function workspaceRow(id): var {
        for (let i = 0; i < niriService.workspaces.count; i++) {
            const row = niriService.workspaces.get(i);
            if (row.id === id)
                return row;
        }
        return null;
    }
    function validTypes(): bool {
        return Number.isInteger(niriService.activeWorkspaceId) && typeof niriService.focusedTitle === "string" && typeof niriService.focusedAppId === "string" && typeof niriService.streamHealthy === "boolean" && typeof niriService.lastError === "string";
    }
    function diagnostics(): var {
        return {
            activeWorkspaceId: niriService.activeWorkspaceId,
            workspaces: workspaceIds(),
            focusedTitle: niriService.focusedTitle,
            focusedAppId: niriService.focusedAppId,
            streamHealthy: niriService.streamHealthy,
            lastError: niriService.lastError
        };
    }
    function writeWorkspaces(list): void {
        workspacesFile.setText(JSON.stringify(list) + "\n");
    }
    function writeFocusedWindow(value): void {
        focusedWindowFile.setText(JSON.stringify(value) + "\n");
    }
    function sendEvent(payload): void {
        Quickshell.execDetached(["niri", "--fixture-write", JSON.stringify(payload)]);
    }
    function sendRawLine(line): void {
        Quickshell.execDetached(["niri", "--fixture-write", line]);
    }
    function actionsLog(): string {
        actionsFile.reload();
        actionsFile.waitForJob();
        return actionsFile.text();
    }
    function lifecycleLog(): string {
        lifecycleFile.reload();
        lifecycleFile.waitForJob();
        return lifecycleFile.text();
    }
    function starts(): int {
        const matches = lifecycleLog().match(/^start /gm);
        return matches ? matches.length : 0;
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
            malformedEventIgnored: root.malformedEventIgnored,
            actionsPassed: root.actionsPassed,
            retryTimingPassed: root.retryTimingPassed,
            exhaustionPassed: root.exhaustionPassed,
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
        id: workspacesFile
        path: root.stateDir + "/workspaces.json"
        blockWrites: true
    }
    FileView {
        id: focusedWindowFile
        path: root.stateDir + "/focused-window.json"
        blockWrites: true
    }
    FileView {
        id: actionsFile
        path: root.stateDir + "/actions.log"
        blockLoading: true
    }
    FileView {
        id: lifecycleFile
        path: root.stateDir + "/niri-lifecycle.log"
        blockAllReads: true
        printErrors: false
    }
    FileView {
        id: autoCrashTwo
        path: root.stateDir + "/auto-crash.2"
        blockWrites: true
    }
    FileView {
        id: autoCrashThree
        path: root.stateDir + "/auto-crash.3"
        blockWrites: true
    }
    FileView {
        id: autoCrashFour
        path: root.stateDir + "/auto-crash.4"
        blockWrites: true
    }

    Component.onCompleted: {
        if (stateDir === "") {
            Qt.exit(2);
            return;
        }
        root.writeWorkspaces([
            {
                id: 1,
                idx: 1,
                is_urgent: false,
                is_active: true,
                is_focused: true,
                active_window_id: 10
            },
            {
                id: 2,
                idx: 2,
                is_urgent: false,
                is_active: false,
                is_focused: false,
                active_window_id: null
            },
            {
                id: 3,
                idx: 3,
                is_urgent: false,
                is_active: false,
                is_focused: false,
                active_window_id: 30
            }
        ]);
        root.writeFocusedWindow({
            id: 10,
            title: "Initial Window",
            app_id: "initial-app"
        });
        readyFile.setText("ready\n");
    }

    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (root.elapsed() > 20000)
                return root.fail("phase timeout");

            if (root.phase === 0) {
                if (root.workspaceIds().length === 3 && niriService.focusedTitle === "Initial Window") {
                    if (!root.validTypes())
                        return root.fail("niri service public contract has invalid types");
                    if (niriService.activeWorkspaceId !== 1)
                        return root.fail("initial active workspace mismatch");
                    if (!niriService.streamHealthy)
                        return root.fail("event stream did not report healthy after initial start");
                    root.advance();
                }
            } else if (root.phase === 1) {
                root.writeWorkspaces([
                    {
                        id: 1,
                        idx: 1,
                        is_urgent: false,
                        is_active: false,
                        is_focused: false,
                        active_window_id: null
                    },
                    {
                        id: 2,
                        idx: 2,
                        is_urgent: true,
                        is_active: true,
                        is_focused: true,
                        active_window_id: 20
                    },
                    {
                        id: 3,
                        idx: 3,
                        is_urgent: false,
                        is_active: false,
                        is_focused: false,
                        active_window_id: 30
                    }
                ]);
                root.sendEvent({
                    WorkspacesChanged: {}
                });
                root.advance();
            } else if (root.phase === 2) {
                if (niriService.activeWorkspaceId === 2) {
                    const one = root.workspaceRow(1);
                    const two = root.workspaceRow(2);
                    const three = root.workspaceRow(3);
                    if (!one || !two || !three)
                        return root.fail("workspace rows missing after WorkspacesChanged reconciliation");
                    if (one.occupied !== false || two.occupied !== true || three.occupied !== true)
                        return root.fail("occupancy did not follow WorkspacesChanged snapshot");
                    if (two.active !== true || one.active !== false)
                        return root.fail("active role did not follow WorkspacesChanged snapshot");
                    if (two.urgent !== true)
                        return root.fail("urgent role did not follow WorkspacesChanged snapshot");
                    root.advance();
                }
            } else if (root.phase === 3) {
                root.writeFocusedWindow({
                    id: 20,
                    title: "Second Window",
                    app_id: "second-app"
                });
                root.sendEvent({
                    WindowFocusChanged: {
                        id: 20
                    }
                });
                root.advance();
            } else if (root.phase === 4) {
                if (niriService.focusedTitle === "Second Window" && niriService.focusedAppId === "second-app") {
                    root.writeFocusedWindow(null);
                    root.sendEvent({
                        WindowFocusChanged: {
                            id: null
                        }
                    });
                    root.advance();
                }
            } else if (root.phase === 5) {
                if (niriService.focusedTitle === "" && niriService.focusedAppId === "") {
                    root.writeFocusedWindow({
                        id: 20,
                        title: "Second Window",
                        app_id: "second-app"
                    });
                    root.sendRawLine("{not valid json at all");
                    root.sendEvent({
                        KeyboardLayoutSwitched: {
                            idx: 1
                        }
                    });
                    root.sendEvent({
                        WindowFocusChanged: {
                            id: 20
                        }
                    });
                    root.advance();
                }
            } else if (root.phase === 6) {
                if (niriService.focusedTitle === "Second Window") {
                    root.malformedEventIgnored = true;
                    niriService.focusWorkspace(3);
                    niriService.focusAdjacent(1);
                    niriService.focusAdjacent(-1);
                    niriService.quitSession();
                    root.advance();
                }
            } else if (root.phase === 7 && root.elapsed() >= 200) {
                const actions = root.actionsLog().trim();
                if (actions !== "focus-workspace 3\nfocus-workspace-down\nfocus-workspace-up\nquit -s")
                    return root.fail("action log mismatch: " + actions);
                root.actionsPassed = true;
                autoCrashTwo.setText("crash\n");
                autoCrashThree.setText("crash\n");
                autoCrashFour.setText("crash\n");
                root.sendRawLine("crash");
                root.advance();
            } else if (root.phase === 8 && root.starts() === 4) {
                const lines = root.lifecycleLog().trim().split("\n");
                const startTimes = [];
                for (const line of lines) {
                    const fields = line.split(" ");
                    if (fields[0] === "start")
                        startTimes.push(Number(fields[3]));
                }
                root.retryTimingPassed = startTimes.length === 4 && startTimes[1] - startTimes[0] >= 200 && startTimes[2] - startTimes[1] >= 450 && startTimes[3] - startTimes[2] >= 900;
                root.advance();
            } else if (root.phase === 9 && root.elapsed() >= 1500) {
                root.exhaustionPassed = root.starts() === 4 && !niriService.streamHealthy && niriService.lastError === "niri event stream is unavailable";
                root.finish();
            }
        }
    }
}
