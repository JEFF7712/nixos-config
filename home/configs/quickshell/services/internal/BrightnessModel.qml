import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool detailedMonitoring: false

    property var _queue: []
    property var _currentJob: null
    property var _sentState: ({})
    property var _pending: ({})
    property string _lastError: ""
    property int _revision: 0

    readonly property var displays: displayModel
    readonly property bool available: displayModel.count > 0
    readonly property int averagePercent: {
        root._revision;
        if (displayModel.count === 0)
            return 0;
        let total = 0;
        for (let i = 0; i < displayModel.count; i++)
            total += displayModel.get(i).percent;
        return Math.round(total / displayModel.count);
    }
    readonly property bool busy: commandProcess.running || _queue.length > 0
    readonly property string lastError: _lastError
    readonly property string _helper: Quickshell.env("QS_BRIGHTNESS_HELPER") || Quickshell.env("HOME") + "/.local/bin/monitor-brightness"

    function _indexOf(id: string): int {
        for (let i = 0; i < displayModel.count; i++) {
            if (displayModel.get(i).id === id)
                return i;
        }
        return -1;
    }

    function displayPercent(id: string): int {
        const index = root._indexOf(id);
        return index < 0 ? 0 : displayModel.get(index).percent;
    }

    function _showPercent(id: string, percent: int): void {
        const index = root._indexOf(id);
        if (index < 0)
            return;
        displayModel.setProperty(index, "percent", percent);
        root._revision++;
    }

    function _applyList(entries: var): void {
        for (let i = displayModel.count - 1; i >= 0; i--) {
            const current = displayModel.get(i);
            if (root._pending[current.id])
                continue;
            let next = null;
            for (let j = 0; j < entries.length; j++) {
                if (entries[j].id === current.id) {
                    next = entries[j];
                    break;
                }
            }
            if (!next)
                displayModel.remove(i);
            else if (current.percent !== next.percent)
                displayModel.setProperty(i, "percent", next.percent);
        }
        for (let k = 0; k < entries.length; k++) {
            const entry = entries[k];
            if (root._indexOf(entry.id) < 0) {
                displayModel.append({
                    id: entry.id,
                    kind: entry.kind,
                    display: entry.display === undefined ? -1 : entry.display,
                    label: entry.label,
                    percent: entry.percent
                });
            }
        }
        root._revision++;
    }

    function refresh(): void {
        if (root._currentJob && root._currentJob.kind === "list")
            return;
        for (let i = 0; i < root._queue.length; i++) {
            if (root._queue[i].kind === "list")
                return;
        }
        root._queue = root._queue.concat([
            {
                kind: "list",
                command: [root._helper, "list"]
            }
        ]);
        root._startNext();
    }

    function setBrightness(id: string, percent: int): void {
        const target = Math.max(0, Math.min(100, Math.round(percent)));
        if (root._sentState[id] === target)
            return;
        root._sentState[id] = target;
        root._pending[id] = true;
        root._showPercent(id, target);
        for (let i = 0; i < root._queue.length; i++) {
            if (root._queue[i].kind === "set" && root._queue[i].id === id) {
                const updated = root._queue[i];
                updated.percent = target;
                updated.command = [root._helper, "set", id, String(target)];
                root._queue[i] = updated;
                return;
            }
        }
        root._queue = root._queue.concat([
            {
                kind: "set",
                id: id,
                percent: target,
                command: [root._helper, "set", id, String(target)]
            }
        ]);
        root._startNext();
    }

    function adjustAll(direction: int): void {
        const step = direction < 0 ? -5 : 5;
        for (let i = 0; i < displayModel.count; i++) {
            const entry = displayModel.get(i);
            root.setBrightness(entry.id, entry.percent + step);
        }
    }

    function _startNext(): void {
        if (commandProcess.running || root._queue.length === 0)
            return;
        root._currentJob = root._queue[0];
        root._queue = root._queue.slice(1);
        commandProcess.command = root._currentJob.command;
        commandProcess.running = true;
    }

    Component.onCompleted: root.refresh()
    Component.onDestruction: {
        root._queue = [];
        commandProcess.running = false;
    }

    onDetailedMonitoringChanged: {
        if (detailedMonitoring)
            root.refresh();
    }

    ListModel {
        id: displayModel
    }

    Process {
        id: commandProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            const job = root._currentJob;
            root._currentJob = null;
            if (job && job.kind === "list") {
                if (exitCode === 0) {
                    try {
                        const parsed = JSON.parse(stdout.text);
                        if (Array.isArray(parsed)) {
                            root._applyList(parsed);
                            root._lastError = "";
                        }
                    } catch (e) {
                        root._lastError = "parse error";
                    }
                } else {
                    root._lastError = "list failed";
                }
            } else if (job) {
                let stillOut = false;
                for (let i = 0; i < root._queue.length; i++) {
                    if (root._queue[i].kind === "set" && root._queue[i].id === job.id) {
                        stillOut = true;
                        break;
                    }
                }
                if (!stillOut)
                    delete root._pending[job.id];
                if (exitCode !== 0) {
                    root._lastError = "set failed";
                    delete root._sentState[job.id];
                    root.refresh();
                } else if (root._lastError === "set failed") {
                    root._lastError = "";
                }
            }
            if (root._queue.length > 0)
                root._startNext();
        }
    }
}
