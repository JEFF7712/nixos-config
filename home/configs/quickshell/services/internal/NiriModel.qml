import QtQuick
import Quickshell
import Quickshell.Io
import "NiriParser.js" as NiriParser

Scope {
    id: root

    property bool _destroyed: false
    property bool _intentionalStop: false
    property bool _stopping: false
    property bool _restartAfterStop: false
    property bool _processExpected: false
    property bool _terminalHandled: true
    property int _retryIndex: 0
    property string _eventBuffer: ""

    property int _activeWorkspaceId: 0
    property var _workspacesData: []
    property string _focusedTitle: ""
    property string _focusedAppId: ""
    property bool _streamHealthy: false
    property string _lastError: ""

    readonly property int activeWorkspaceId: _activeWorkspaceId
    property alias workspaces: workspacesModel
    readonly property string focusedTitle: _focusedTitle
    readonly property string focusedAppId: _focusedAppId
    readonly property bool streamHealthy: _streamHealthy
    readonly property string lastError: _lastError

    ListModel {
        id: workspacesModel
    }

    function _stateObject(): var {
        return {
            activeWorkspaceId: root._activeWorkspaceId,
            workspaces: root._workspacesData,
            focusedTitle: root._focusedTitle,
            focusedAppId: root._focusedAppId,
            lastError: root._lastError
        };
    }

    // Reconciles the ListModel in place: a stable id sequence updates only
    // the roles that changed, so bound delegates (and any Behavior
    // animations on them) are not torn down every poll or event.
    function _applyWorkspacesModel(list): void {
        if (list.length !== workspacesModel.count) {
            workspacesModel.clear();
            for (const ws of list)
                workspacesModel.append(ws);
            return;
        }
        for (let i = 0; i < list.length; i++) {
            const row = list[i];
            const existing = workspacesModel.get(i);
            if (existing.id !== row.id) {
                workspacesModel.clear();
                for (const ws of list)
                    workspacesModel.append(ws);
                return;
            }
            if (existing.occupied !== row.occupied)
                workspacesModel.setProperty(i, "occupied", row.occupied);
            if (existing.active !== row.active)
                workspacesModel.setProperty(i, "active", row.active);
            if (existing.urgent !== row.urgent)
                workspacesModel.setProperty(i, "urgent", row.urgent);
        }
    }

    function _applyWorkspacesSnapshot(text, exitCode): void {
        const next = NiriParser.reduceWorkspacesSnapshot(root._stateObject(), text, exitCode);
        root._activeWorkspaceId = next.activeWorkspaceId;
        root._workspacesData = next.workspaces;
        root._lastError = next.lastError;
        root._applyWorkspacesModel(next.workspaces);
    }

    function _applyFocusedWindowSnapshot(text, exitCode): void {
        const next = NiriParser.reduceFocusedWindowSnapshot(root._stateObject(), text, exitCode);
        root._focusedTitle = next.focusedTitle;
        root._focusedAppId = next.focusedAppId;
        root._lastError = next.lastError;
    }

    function _requestWorkspaces(): void {
        if (workspacesProcess.running)
            return;
        workspacesProcess.running = true;
    }

    function _requestFocusedWindow(): void {
        if (focusedWindowProcess.running)
            return;
        focusedWindowProcess.running = true;
    }

    function _reconcile(): void {
        root._requestWorkspaces();
        root._requestFocusedWindow();
    }

    function focusWorkspace(id: int): void {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(id)]);
    }

    function focusAdjacent(direction: int): void {
        Quickshell.execDetached(["niri", "msg", "action", direction < 0 ? "focus-workspace-up" : "focus-workspace-down"]);
    }

    function quitSession(): void {
        Quickshell.execDetached(["niri", "msg", "action", "quit", "-s"]);
    }

    function _handleEventLine(line): void {
        const result = NiriParser.classifyEventLine(line);
        if (!result.ok)
            return;
        // Any classifiable event line is proof the stream is alive, even
        // for event classes we otherwise ignore.
        root._retryIndex = 0;
        retryTimer.stop();
        root._streamHealthy = true;
        if (result.kind === "workspaces")
            root._requestWorkspaces();
        else if (result.kind === "focused-window")
            root._requestFocusedWindow();
    }

    function _consumeEventChunk(data): void {
        const parsed = NiriParser.consumeEventChunk(root._eventBuffer, data);
        root._eventBuffer = parsed.buffer;
        for (const line of parsed.lines)
            root._handleEventLine(line);
    }

    function _startStream(): void {
        if (root._destroyed)
            return;
        if (root._stopping) {
            root._restartAfterStop = true;
            return;
        }
        if (eventStreamProcess.running || retryTimer.running)
            return;
        root._intentionalStop = false;
        root._processExpected = true;
        root._terminalHandled = false;
        root._eventBuffer = "";
        terminalFallback.stop();
        eventStreamProcess.running = true;
    }

    function _handleStreamTermination(): void {
        if (root._terminalHandled)
            return;
        root._terminalHandled = true;
        root._processExpected = false;
        root._streamHealthy = false;
        if (root._stopping) {
            root._stopping = false;
            const restart = root._restartAfterStop && !root._destroyed;
            root._restartAfterStop = false;
            root._intentionalStop = false;
            if (restart)
                root._startStream();
            return;
        }
        if (root._intentionalStop || root._destroyed)
            return;
        if (root._retryIndex >= 3) {
            root._lastError = "niri event stream is unavailable";
            return;
        }
        retryTimer.interval = [250, 500, 1000][root._retryIndex];
        root._retryIndex++;
        retryTimer.start();
    }

    function _stopStream(): void {
        root._intentionalStop = true;
        retryTimer.stop();
        root._retryIndex = 0;
        root._restartAfterStop = false;
        root._streamHealthy = false;
        if (eventStreamProcess.running) {
            root._stopping = true;
            eventStreamProcess.running = false;
        }
    }

    Process {
        id: workspacesProcess
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root._applyWorkspacesSnapshot(stdout.text, exitCode);
        }
    }

    Process {
        id: focusedWindowProcess
        command: ["niri", "msg", "-j", "focused-window"]
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root._applyFocusedWindowSnapshot(stdout.text, exitCode);
        }
    }

    Process {
        id: eventStreamProcess
        command: ["setpriv", "--pdeathsig", "TERM", "--", "niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root._consumeEventChunk(data)
        }
        onRunningChanged: {
            if (!running && root._processExpected && !root._terminalHandled)
                terminalFallback.restart();
        }
        onExited: {
            terminalFallback.stop();
            root._handleStreamTermination();
        }
    }

    Timer {
        id: terminalFallback
        interval: 0
        repeat: false
        onTriggered: root._handleStreamTermination()
    }

    Timer {
        id: retryTimer
        repeat: false
        onTriggered: root._startStream()
    }

    Timer {
        id: reconcileTimer
        interval: 30000
        running: true
        repeat: true
        onTriggered: root._reconcile()
    }

    Component.onCompleted: {
        root._requestWorkspaces();
        root._requestFocusedWindow();
        root._startStream();
    }
    Component.onDestruction: {
        root._destroyed = true;
        root._stopStream();
    }
}
