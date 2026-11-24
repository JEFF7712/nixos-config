pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Stands in for Quickshell.I3 and the swaymsg tree: niri's workspaces are
// named by their index on each output, so desks read as "1", "2", ...
QtObject {
    id: niri
    property var workspaces: []
    property var windows: []
    property var showing: ({})
    property string focusedOutput: ""

    function deskName(ws): string {
        return ws.name || String(ws.idx);
    }
    function action(args): void {
        Quickshell.execDetached(["niri", "msg", "action"].concat(args));
    }
    function focusDesk(desk: string): void {
        const ws = workspaces.find(w => w.name === desk && w.output === focusedOutput) || workspaces.find(w => w.name === desk);
        if (ws)
            action(["focus-workspace", ws.ref]);
        else
            action(["focus-workspace", desk]);
    }
    function focusWindow(id): void {
        action(["focus-window", "--id", String(id)]);
    }
    function moveDesk(from: string, to: string): void {
        const target = workspaces.find(w => w.name === to);
        if (!target)
            return;
        for (const w of windows.filter(w => w.workspace === from))
            action(["move-window-to-workspace", "--window-id", String(w.id), "--focus", "false", target.ref]);
    }
    function quit(): void {
        action(["quit", "--skip-confirmation"]);
    }

    property var rawWorkspaces: []
    property var rawWindows: []
    function rebuild(): void {
        const names = {};
        const next = rawWorkspaces.slice().sort((a, b) => a.idx - b.idx).map(ws => {
            const name = deskName(ws);
            names[ws.id] = name;
            return {
                id: ws.id,
                name: name,
                ref: ws.name || String(ws.idx),
                output: ws.output || "",
                monitor: {
                    name: ws.output || ""
                },
                active: !!ws.is_active,
                focused: !!ws.is_focused,
                urgent: !!ws.is_urgent
            };
        });
        const seen = {};
        let focused = "";
        for (const ws of next) {
            if (ws.active)
                seen[ws.output] = ws.name;
            if (ws.focused)
                focused = ws.output;
        }
        workspaces = next;
        showing = seen;
        if (focused)
            focusedOutput = focused;
        windows = rawWindows.filter(w => w.workspace_id !== null && names[w.workspace_id] !== undefined).map(w => ({
                    id: w.id,
                    app: String(w.app_id || ""),
                    title: String(w.title || ""),
                    workspace: names[w.workspace_id],
                    focused: !!w.is_focused,
                    urgent: !!w.is_urgent
                }));
    }

    function refresh(): void {
        debounce.restart();
    }
    property Timer debounce: Timer {
        interval: 40
        onTriggered: {
            if (!wsQuery.running)
                wsQuery.running = true;
            if (!winQuery.running)
                winQuery.running = true;
        }
    }
    property Process wsQuery: Process {
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    niri.rawWorkspaces = JSON.parse(text);
                    niri.rebuild();
                } catch (error) {
                    console.warn("Folio workspaces:", error);
                }
            }
        }
    }
    property Process winQuery: Process {
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    niri.rawWindows = JSON.parse(text);
                    niri.rebuild();
                } catch (error) {
                    console.warn("Folio windows:", error);
                }
            }
        }
    }
    property Process events: Process {
        command: ["setpriv", "--pdeathsig", "TERM", "--", "niri", "msg", "-j", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("Workspace") !== -1 || line.indexOf("Window") !== -1)
                    niri.refresh();
            }
        }
    }
    property Timer reconnect: Timer {
        interval: 1000
        running: !niri.events.running
        repeat: true
        onTriggered: niri.events.running = true
    }
    Component.onCompleted: refresh()
}
