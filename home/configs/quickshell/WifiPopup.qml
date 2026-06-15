import QtQuick
import Quickshell
import Quickshell.Io

InfoPopup {
    id: root
    title: "NETWORK"

    property bool wifiEnabled: false
    property string activeSsid: ""
    property int activeSignal: 0
    property string activeSecurity: ""
    property string busySsid: ""
    property var networks: []

    function signalIcon(signal) {
        if (signal > 75)
            return "󰤨";
        if (signal > 50)
            return "󰤥";
        if (signal > 25)
            return "󰤢";
        return "󰤟";
    }

    function networkMeta(network) {
        const parts = [];
        if (network.secure)
            parts.push(network.security);
        else
            parts.push("open");
        if (network.saved)
            parts.push("saved");
        parts.push(network.signal + "%");
        return parts.join("  ");
    }

    function statusLabel() {
        if (!root.wifiEnabled)
            return "wifi disabled";
        if (root.activeSsid)
            return root.activeSsid;
        return "not connected";
    }

    function statusMeta() {
        if (!root.wifiEnabled)
            return "radio off";
        if (root.activeSsid) {
            const sec = root.activeSecurity || "open";
            return sec + "  " + root.activeSignal + "%";
        }
        if (root.networks.length > 0)
            return root.networks.length + " networks visible";
        return "no networks visible";
    }

    Item {
        width: parent.width
        height: 26

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.statusLabel()
            color: root.wifiEnabled ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.48)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 11
                weight: Font.Medium
            }
            elide: Text.ElideRight
            width: parent.width - toggleRow.width - 10
        }

        Row {
            id: toggleRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            InfoToggle {
                width: 32
                label: ""
                checked: root.wifiEnabled
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                themeRawBg: root.themeRawBg
                dividerColor: root.dividerColor
                onToggled: {
                    toggleProc.target = root.wifiEnabled ? "off" : "on";
                    toggleProc.running = true;
                }
            }
        }
    }

    Text {
        width: parent.width
        text: root.statusMeta()
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.42)
        font {
            family: "JetBrainsMono Nerd Font"
            pixelSize: 9
        }
        elide: Text.ElideRight
        visible: root.statusMeta() !== ""
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
        visible: root.wifiEnabled
    }

    Repeater {
        model: root.wifiEnabled ? root.networks : []

        delegate: Item {
            id: networkRow
            width: parent.width
            height: 36

            readonly property bool activeNetwork: modelData.ssid === root.activeSsid

            Rectangle {
                anchors.fill: parent
                radius: root.flatMode ? 0 : 6
                color: rowMouse.pressed ? Qt.rgba(1, 1, 1, 0.08) : rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                id: signalText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 6
                text: root.signalIcon(modelData.signal)
                color: networkRow.activeNetwork ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.62)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 12
                }
            }

            Column {
                anchors.left: signalText.right
                anchors.right: stateText.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 1

                Text {
                    width: parent.width
                    text: modelData.ssid
                    color: networkRow.activeNetwork ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.88)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 10
                        weight: networkRow.activeNetwork ? Font.Medium : Font.Normal
                    }
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.networkMeta(modelData)
                    color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.42)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 8
                    }
                    elide: Text.ElideRight
                }
            }

            Text {
                id: stateText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 6
                text: modelData.ssid === root.busySsid ? "..." : (networkRow.activeNetwork ? "on" : "")
                color: networkRow.activeNetwork ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.46)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 9
                    weight: Font.Medium
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: modelData.ssid === root.busySsid ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                onClicked: {
                    if (modelData.ssid === root.activeSsid || modelData.ssid === root.busySsid)
                        return;
                    root.busySsid = modelData.ssid;
                    if (modelData.saved) {
                        connectProc.target = modelData.ssid;
                        connectProc.running = true;
                    } else {
                        Quickshell.execDetached(["kitty", "-e", "nmtui-connect", modelData.ssid]);
                        root.close();
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        text: root.wifiEnabled ? "no networks visible" : "radio is off"
        visible: !root.wifiEnabled || root.networks.length === 0
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.36)
        font {
            family: "JetBrainsMono Nerd Font"
            pixelSize: 9
            italic: true
        }
        horizontalAlignment: Text.AlignHCenter
        topPadding: 8
        bottomPadding: 8
    }

    Process {
        id: fetchProc
        command: ["sh", "-c", "echo \"radio|$(nmcli radio wifi 2>/dev/null)\";" + "nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2==\"802-11-wireless\"{print \"saved|\"$1}';" + "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi 2>/dev/null | awk -F: 'NF>=4 && $2!=\"\"{print \"net|\"$1\"|\"$2\"|\"$3\"|\"$4}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                const saved = {};
                const nets = [];
                let active = "";
                let activeSignal = 0;
                let activeSecurity = "";
                let radio = false;

                for (const raw of lines) {
                    const l = raw.trim();
                    if (!l)
                        continue;
                    if (l.startsWith("radio|")) {
                        radio = l.substring(6) === "enabled";
                    } else if (l.startsWith("saved|")) {
                        saved[l.substring(6)] = true;
                    } else if (l.startsWith("net|")) {
                        const f = l.substring(4).split("|");
                        const inUse = f[0];
                        const ssid = f[1];
                        const sig = parseInt(f[2]) || 0;
                        const sec = f[3] || "";
                        const secure = sec !== "" && sec !== "--";
                        if (inUse === "*") {
                            active = ssid;
                            activeSignal = sig;
                            activeSecurity = secure ? sec : "open";
                        }
                        nets.push({
                            ssid: ssid,
                            signal: sig,
                            security: secure ? sec : "open",
                            secure: secure
                        });
                    }
                }

                const seen = {};
                const deduped = [];
                nets.sort((a, b) => b.signal - a.signal);
                for (const n of nets) {
                    if (seen[n.ssid])
                        continue;
                    seen[n.ssid] = true;
                    n.saved = !!saved[n.ssid] || n.ssid === active;
                    deduped.push(n);
                    if (deduped.length >= 8)
                        break;
                }

                root.wifiEnabled = radio;
                root.activeSsid = active;
                root.activeSignal = activeSignal;
                root.activeSecurity = activeSecurity;
                root.networks = deduped;
                if (root.busySsid && (root.busySsid === active || !deduped.some(n => n.ssid === root.busySsid))) {
                    root.busySsid = "";
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
            root.busySsid = "";
            fetchProc.running = true;
        }
    }

    onShownChanged: {
        if (shown)
            fetchProc.running = true;
    }

    Timer {
        running: true
        interval: root.shown ? 5000 : 20000
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }
}
