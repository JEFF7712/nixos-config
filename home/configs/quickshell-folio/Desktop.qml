pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Logic.js" as Logic

QtObject {
    id: desktop
    readonly property var windows: Niri.windows
    readonly property var showing: Niri.showing
    readonly property var occupied: Array.from(new Set(windows.map(w => w.workspace)))
    property var recent: ({})
    property FileView history: FileView {
        path: Theme.stateHome + "/ws/state.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                desktop.recent = JSON.parse(text()).recent || {};
            } catch (_) {
                desktop.recent = {};
            }
        }
    }
    property var waitingSince: ({})
    function noteWaiting(desks): void {
        const next = {};
        let changed = Object.keys(waitingSince).length !== desks.length;
        for (const desk of desks) {
            next[desk] = waitingSince[desk] || new Date();
            changed = changed || !waitingSince[desk];
        }
        if (changed)
            waitingSince = next;
    }
    property var spans: []
    property var lastSeen: ({})
    property string today: Logic.dayKey(Date.now())
    property string notedDesk: ""
    property bool notedBusy: false
    function note(): void {
        const now = Date.now();
        const key = Logic.dayKey(now);
        let next = spans;
        if (key !== today) {
            next = [];
            today = key;
        }
        const output = Object.keys(showing)[0];
        const desk = output ? showing[output] : "";
        notedDesk = desk;
        notedBusy = windows.some(w => w.workspace === desk);
        if (desk && !ShellState.locked && notedBusy) {
            next = Logic.noteSpan(next, now, desk, Logic.deskName(windows, desk));
            const seen = Object.assign({}, lastSeen);
            seen[desk] = now;
            lastSeen = seen;
        }
        spans = next;
    }
    property FileView dayFile: FileView {
        path: Quickshell.statePath("day-" + desktop.today + ".json")
        printErrors: false
        atomicWrites: true
        onLoaded: {
            if (desktop.spans.length > 0)
                return;
            try {
                const value = JSON.parse(text());
                if (Array.isArray(value)) {
                    desktop.spans = value;
                    const seen = {};
                    for (const span of value)
                        seen[span.desk] = Math.max(seen[span.desk] || 0, span.to);
                    desktop.lastSeen = Object.assign(seen, desktop.lastSeen);
                }
            } catch (_) {}
        }
    }
    property Timer minute: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            desktop.note();
            if (desktop.spans.length > 0)
                desktop.dayFile.setText(JSON.stringify(desktop.spans));
        }
    }
    function iconFor(app: string): string {
        const entry = DesktopEntries.heuristicLookup(app);
        const name = entry?.icon || app;
        if (!name)
            return "";
        if (name.startsWith("/"))
            return "file://" + name;
        return Quickshell.hasThemeIcon(name) ? Quickshell.iconPath(name) : "";
    }
    function check(): void {
        const shown = showing[Object.keys(showing)[0]] ?? "";
        if (shown !== notedDesk || windows.some(w => w.workspace === shown) !== notedBusy)
            note();
    }
    onWindowsChanged: check()
    onShowingChanged: check()
}
