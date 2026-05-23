import QtQuick
import Quickshell
import Quickshell.Io

InfoPopup {
    id: root
    title: "NETWORK"

    property bool wifiEnabled: false
    property string activeSsid: ""
    property string busySsid: ""
    property var networks: []

    InfoToggle {
        label: "wifi"
        checked: root.wifiEnabled
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        onToggled: {
            toggleProc.target = root.wifiEnabled ? "off" : "on"
            toggleProc.running = true
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
        visible: root.wifiEnabled
    }

    Repeater {
        model: root.wifiEnabled ? root.networks : []
        delegate: ActionRow {
            themeFg: root.themeFg
            themeAccent: root.themeAccent
            icon: modelData.signal > 75 ? "󰤨"
                : modelData.signal > 50 ? "󰤥"
                : modelData.signal > 25 ? "󰤢"
                : "󰤟"
            label: modelData.ssid + (modelData.secure ? "  󰌾" : "")
            hint: (modelData.ssid === root.activeSsid)
                ? "connected"
                : (modelData.saved ? "saved" : "")
            active: modelData.ssid === root.activeSsid
            busy: modelData.ssid === root.busySsid
            onActivated: {
                if (modelData.ssid === root.activeSsid) return
                root.busySsid = modelData.ssid
                if (modelData.saved) {
                    connectProc.target = modelData.ssid
                    connectProc.running = true
                } else {
                    Quickshell.execDetached(["kitty", "-e", "nmtui-connect", modelData.ssid])
                    root.close()
                }
            }
        }
    }

    Text {
        width: parent.width
        text: "no networks visible"
        visible: root.wifiEnabled && root.networks.length === 0
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.4)
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; italic: true }
        horizontalAlignment: Text.AlignHCenter
        topPadding: 8
        bottomPadding: 8
    }

    Process {
        id: fetchProc
        command: ["sh", "-c",
            "echo \"radio|$(nmcli radio wifi 2>/dev/null)\";" +
            "nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2==\"802-11-wireless\"{print \"saved|\"$1}';" +
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi 2>/dev/null | awk -F: 'NF>=4 && $2!=\"\"{print \"net|\"$1\"|\"$2\"|\"$3\"|\"$4}'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const saved = {}
                const nets = []
                let active = ""
                let radio = false
                for (const raw of lines) {
                    const l = raw.trim()
                    if (!l) continue
                    if (l.startsWith("radio|")) {
                        radio = l.substring(6) === "enabled"
                    } else if (l.startsWith("saved|")) {
                        saved[l.substring(6)] = true
                    } else if (l.startsWith("net|")) {
                        const f = l.substring(4).split("|")
                        const inUse = f[0]
                        const ssid = f[1]
                        const sig = parseInt(f[2]) || 0
                        const sec = f[3] || ""
                        if (inUse === "*") active = ssid
                        nets.push({
                            ssid: ssid,
                            signal: sig,
                            secure: sec !== "" && sec !== "--"
                        })
                    }
                }
                const seen = {}
                const deduped = []
                nets.sort((a, b) => b.signal - a.signal)
                for (const n of nets) {
                    if (seen[n.ssid]) continue
                    seen[n.ssid] = true
                    n.saved = !!saved[n.ssid] || n.ssid === active
                    deduped.push(n)
                    if (deduped.length >= 8) break
                }
                root.wifiEnabled = radio
                root.activeSsid = active
                root.networks = deduped
                if (root.busySsid && (root.busySsid === active || !deduped.some(n => n.ssid === root.busySsid))) {
                    root.busySsid = ""
                }
            }
        }
    }

    Process {
        id: toggleProc
        property string target: "on"
        command: ["nmcli", "radio", "wifi", toggleProc.target]
        onExited: fetchProc.running = true
    }

    Process {
        id: connectProc
        property string target: ""
        command: ["nmcli", "dev", "wifi", "connect", connectProc.target]
        onExited: {
            root.busySsid = ""
            fetchProc.running = true
        }
    }

    onShownChanged: { if (shown) fetchProc.running = true }

    Timer {
        running: root.shown
        interval: 5000
        repeat: true
        onTriggered: fetchProc.running = true
    }
}
