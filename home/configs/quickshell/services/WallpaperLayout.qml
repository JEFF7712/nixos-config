import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    required property string screenName
    required property real viewportWidth
    required property real viewportHeight
    required property var candidates
    property color foreground: "#ffffff"
    property color accent: "#ffffff"
    property bool enabled: false
    property var result: null
    property int revision: 0
    property int activeRevision: -1
    property bool resultReceived: false
    property var helperCommand: ["iris-python", Qt.resolvedUrl("internal/wallpaper_layout.py").toString().replace(/^file:\/\//, "")]
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    readonly property string request: JSON.stringify({
        screen: root.screenName,
        width: root.viewportWidth,
        height: root.viewportHeight,
        candidates: root.candidates,
        foreground: [root.foreground.r, root.foreground.g, root.foreground.b],
        accent: [root.accent.r, root.accent.g, root.accent.b]
    })

    function refresh(): void {
        root.revision++;
        if (root.enabled)
            debounce.restart();
    }

    function fallbackPose(): var {
        const candidate = root.candidates.find(c => c.name === "compact") || root.candidates[0];
        const scale = Math.max(0.01, Math.min(1, (root.viewportWidth - 48) / candidate.width, (root.viewportHeight - 48) / candidate.height));
        const lightText = root.foreground.r + root.foreground.g + root.foreground.b > 1.5;
        return {
            name: candidate.name,
            x: (root.viewportWidth - candidate.width * scale) / 2,
            y: (root.viewportHeight - candidate.height * scale) / 2,
            scale: scale,
            backdropOpacity: 1,
            backdropColor: lightText ? "#000000" : "#ffffff",
            foreground: lightText ? "#ffffff" : "#111111",
            accent: lightText ? "#ffffff" : "#111111",
            available: false
        };
    }

    function validPose(pose): bool {
        if (!pose)
            return false;
        const candidate = root.candidates.find(c => c.name === pose.name);
        return candidate !== undefined && Number.isFinite(pose.x) && Number.isFinite(pose.y) && Number.isFinite(pose.scale) && pose.scale > 0 && pose.scale <= 1 && pose.x >= 0 && pose.y >= 0 && pose.x + candidate.width * pose.scale <= root.viewportWidth + 0.1 && pose.y + candidate.height * pose.scale <= root.viewportHeight + 0.1 && Number.isFinite(pose.backdropOpacity) && pose.backdropOpacity >= 0 && pose.backdropOpacity <= 1 && /^#[0-9a-f]{6}$/i.test(pose.backdropColor) && /^#[0-9a-f]{6}$/i.test(pose.accent);
    }

    onRequestChanged: root.refresh()
    onEnabledChanged: if (root.enabled)
        root.refresh()
    Component.onCompleted: root.refresh()

    FileView {
        path: root.configHome + "/waypaper/config.ini"
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
    }

    FileView {
        path: root.configHome + "/desktop-profiles/quickshell-theme-reload"
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
    }

    FileView {
        path: root.configHome + "/desktop-profiles/idle-layout.json"
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
    }

    Timer {
        id: debounce
        interval: 180
        onTriggered: {
            if (!root.enabled || probe.running || root.viewportWidth <= 0 || root.viewportHeight <= 0)
                return;
            root.activeRevision = root.revision;
            root.resultReceived = false;
            probe.command = root.helperCommand.concat([root.request]);
            probe.running = true;
        }
    }

    Process {
        id: probe
        onRunningChanged: {
            if (running)
                timeout.restart();
            else
                timeout.stop();
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.activeRevision !== root.revision)
                    return;
                try {
                    const pose = JSON.parse(this.text);
                    if (!root.validPose(pose))
                        throw new Error("Invalid layout result");
                    root.result = pose;
                    root.resultReceived = true;
                } catch (error) {
                    console.warn("Wallpaper layout analysis failed:", error);
                }
            }
        }
        onExited: {
            if (root.activeRevision !== root.revision && root.enabled)
                debounce.restart();
            else if (!root.resultReceived)
                root.result = root.fallbackPose();
        }
    }

    Timer {
        id: timeout
        interval: 15000
        onTriggered: probe.running = false
    }
}
