import QtQuick
import Quickshell
import Quickshell.Io

// Runs a ~/.local/bin helper that prints one JSON object, on an interval, only
// while `active`. Keeps the last good result across failures.
Scope {
    id: root

    required property string script
    property int intervalMs: 60000
    property bool active: false

    property var result: null
    property string lastError: ""
    property int failures: 0
    readonly property bool loaded: root.result !== null

    function refresh(): void {
        if (!proc.running)
            proc.running = true;
    }

    onActiveChanged: if (root.active)
        root.refresh()

    Timer {
        interval: root.intervalMs
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: proc
        command: ["setpriv", "--pdeathsig", "TERM", "--", Quickshell.env("HOME") + "/.local/bin/" + root.script]
        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                try {
                    root.result = JSON.parse(out.text.trim());
                    root.lastError = "";
                    root.failures = 0;
                } catch (e) {
                    root.lastError = root.script + ": no JSON output";
                    // One miss keeps the last result; a second clears it rather than showing stale data.
                    root.failures++;
                    if (root.failures >= 2)
                        root.result = null;
                }
            }
        }
    }
}
