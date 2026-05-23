import QtQuick
import Quickshell
import Quickshell.Io

InfoPopup {
    id: root
    title: "BLUETOOTH"

    property string adapter: ""
    property bool btEnabled: false
    property string busyPath: ""
    property var devices: []

    InfoToggle {
        label: "bluetooth"
        checked: root.btEnabled
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        onToggled: {
            if (!root.adapter) return
            toggleProc.target = root.btEnabled ? "false" : "true"
            toggleProc.running = true
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
        visible: root.btEnabled
    }

    Repeater {
        model: root.btEnabled ? root.devices : []
        delegate: ActionRow {
            themeFg: root.themeFg
            themeAccent: root.themeAccent
            icon: modelData.connected ? "󰂱" : "󰂯"
            label: modelData.name
            hint: modelData.connected ? "connected" : ""
            active: modelData.connected
            busy: modelData.path === root.busyPath
            onActivated: {
                root.busyPath = modelData.path
                actionProc.target = modelData.path
                actionProc.method = modelData.connected ? "Disconnect" : "Connect"
                actionProc.running = true
            }
        }
    }

    Text {
        width: parent.width
        text: "no paired devices"
        visible: root.btEnabled && root.devices.length === 0
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.4)
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; italic: true }
        horizontalAlignment: Text.AlignHCenter
        topPadding: 8
        bottomPadding: 8
    }

    Process {
        id: fetchProc
        command: ["sh", "-c",
            "a=$(busctl --system tree org.bluez 2>/dev/null | grep -oE '/org/bluez/hci[0-9]+' | head -1);" +
            "echo \"adapter|$a\";" +
            "[ -z \"$a\" ] && exit 0;" +
            "echo \"powered|$(busctl --system get-property org.bluez \"$a\" org.bluez.Adapter1 Powered 2>/dev/null | awk '{print $2}')\";" +
            "busctl --system tree org.bluez 2>/dev/null | grep -oE \"$a/dev_[A-F0-9_]+\" | sort -u | while read dev; do" +
            "  paired=$(busctl --system get-property org.bluez \"$dev\" org.bluez.Device1 Paired 2>/dev/null | awk '{print $2}');" +
            "  [ \"$paired\" != 'true' ] && continue;" +
            "  conn=$(busctl --system get-property org.bluez \"$dev\" org.bluez.Device1 Connected 2>/dev/null | awk '{print $2}');" +
            "  name=$(busctl --system get-property org.bluez \"$dev\" org.bluez.Device1 Alias 2>/dev/null | sed -E 's/^s \"(.*)\"$/\\1/');" +
            "  echo \"dev|$dev|$conn|$name\";" +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const devs = []
                let adapter = ""
                let powered = false
                for (const raw of lines) {
                    const l = raw.trim()
                    if (!l) continue
                    if (l.startsWith("adapter|")) {
                        adapter = l.substring(8)
                    } else if (l.startsWith("powered|")) {
                        powered = l.substring(8) === "true"
                    } else if (l.startsWith("dev|")) {
                        const f = l.substring(4).split("|")
                        devs.push({
                            path: f[0],
                            connected: f[1] === "true",
                            name: f[2] || "Unknown"
                        })
                    }
                }
                devs.sort((a, b) => {
                    if (a.connected !== b.connected) return b.connected - a.connected
                    return a.name.localeCompare(b.name)
                })
                root.adapter = adapter
                root.btEnabled = powered
                root.devices = devs
                if (root.busyPath && !devs.some(d => d.path === root.busyPath)) {
                    root.busyPath = ""
                }
            }
        }
    }

    Process {
        id: toggleProc
        property string target: "true"
        command: [
            "busctl", "--system", "set-property",
            "org.bluez", root.adapter, "org.bluez.Adapter1",
            "Powered", "b", toggleProc.target
        ]
        onExited: fetchProc.running = true
    }

    Process {
        id: actionProc
        property string target: ""
        property string method: "Connect"
        command: [
            "busctl", "--system", "call",
            "org.bluez", actionProc.target,
            "org.bluez.Device1", actionProc.method
        ]
        onExited: {
            root.busyPath = ""
            fetchProc.running = true
        }
    }

    onShownChanged: { if (shown) fetchProc.running = true }

    Timer {
        running: root.shown
        interval: 4000
        repeat: true
        onTriggered: fetchProc.running = true
    }
}
