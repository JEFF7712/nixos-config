pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property var colors: ({})
    // who.json is the fallback; with a Home Assistant tracker named there,
    // the place and coordinates follow it live.
    property var fixedWho: ({})
    readonly property var who: {
        const base = fixedWho;
        const home = Machine.home;
        home.stateRevision;
        const tracker = base.tracker ? home.states[base.tracker] : null;
        const lat = tracker?.attributes?.latitude;
        const lon = tracker?.attributes?.longitude;
        if (typeof lat !== "number" || typeof lon !== "number")
            return base;
        const geo = base.geocoded ? home.states[base.geocoded] : null;
        const city = geo?.attributes?.Locality || geo?.attributes?.["Sub Administrative Area"] || base.city || "";
        return Object.assign({}, base, {
            city: city,
            place: city,
            latitude: lat.toFixed(2),
            longitude: lon.toFixed(2)
        });
    }
    readonly property color bg: colors.bg || "#0d0d0e"
    readonly property color fg: colors.fg || "#e6e1d5"
    readonly property color dim: colors.dim || "#8b877d"
    readonly property color faint: colors.surface_alt || "#343330"
    readonly property color signal: colors.red || "#ff4a2b"
    readonly property string mono: "Departure Mono"
    readonly property string serif: "Newsreader"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
    readonly property string pagePath: stateHome + "/folio/page.png"
    function unit(screen): real {
        return screen ? Math.min(1, screen.height / 1440) : 1;
    }
    function small(screen): int {
        return !screen || screen.height >= 1300 ? 22 : 11;
    }
    property FileView palette: FileView {
        path: root.configHome + "/folio/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.colors = JSON.parse(text());
            } catch (error) {
                console.warn("Folio palette:", error);
            }
        }
    }
    property FileView whoFile: FileView {
        path: root.configHome + "/folio/who.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.fixedWho = JSON.parse(text());
            } catch (error) {
                console.warn("Folio who:", error);
            }
        }
    }
}
