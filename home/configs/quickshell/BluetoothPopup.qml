import QtQuick
import Quickshell.Io

InfoPopup {
    id: root
    title: "BLUETOOTH"

    property string adapter: ""
    property bool btEnabled: false
    property string busyPath: ""
    property var devices: []

    readonly property int connectedCount: root.devices.filter(d => d.connected).length

    function statusLabel() {
        if (!root.adapter)
            return "no adapter";
        if (!root.btEnabled)
            return "bluetooth disabled";
        if (root.connectedCount > 0)
            return root.connectedCount + " connected";
        return "not connected";
    }

    function statusMeta() {
        if (!root.adapter)
            return "bluez adapter unavailable";
        if (!root.btEnabled)
            return "";
        if (root.devices.length === 0)
            return "no paired devices";
        return root.devices.length + " paired";
    }

    function deviceMeta(device) {
        if (device.connected)
            return "connected";
        return "paired";
    }

    function rowBackgroundColor(pressed, hovered) {
        if (pressed)
            return Qt.rgba(1, 1, 1, 0.08);
        if (hovered)
            return Qt.rgba(1, 1, 1, 0.05);
        return "transparent";
    }

    Item {
        width: parent.width
        height: 26

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - toggleRow.width - 10
            text: root.statusLabel()
            color: root.btEnabled && root.adapter !== "" ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.48)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 11
                weight: Font.Medium
            }
            elide: Text.ElideRight
        }

        Row {
            id: toggleRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            InfoToggle {
                width: 32
                label: ""
                checked: root.btEnabled
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                themeRawBg: root.themeRawBg
                dividerColor: root.dividerColor
                onToggled: {
                    if (!root.adapter)
                        return;
                    toggleProc.target = root.btEnabled ? "false" : "true";
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
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
        visible: root.btEnabled
    }

    Repeater {
        model: root.btEnabled ? root.devices : []

        delegate: Item {
            id: deviceRow
            width: parent.width
            height: 36

            Rectangle {
                anchors.fill: parent
                radius: root.flatMode ? 0 : 6
                color: root.rowBackgroundColor(rowMouse.pressed, rowMouse.containsMouse)
                Behavior on color {
                    ColorAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                id: deviceIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 6
                text: modelData.connected ? "󰂱" : "󰂯"
                color: modelData.connected ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.62)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 12
                }
            }

            Column {
                anchors.left: deviceIcon.right
                anchors.right: stateText.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 1

                Text {
                    width: parent.width
                    text: modelData.name
                    color: modelData.connected ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.88)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 10
                        weight: modelData.connected ? Font.Medium : Font.Normal
                    }
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.deviceMeta(modelData)
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
                text: modelData.path === root.busyPath ? "..." : (modelData.connected ? "on" : "")
                color: modelData.connected ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.46)
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
                cursorShape: modelData.path === root.busyPath ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                onClicked: {
                    if (modelData.path === root.busyPath)
                        return;
                    root.busyPath = modelData.path;
                    actionProc.target = modelData.path;
                    actionProc.method = modelData.connected ? "Disconnect" : "Connect";
                    actionProc.running = true;
                }
            }
        }
    }

    Text {
        width: parent.width
        text: "no paired devices"
        visible: root.btEnabled && root.devices.length === 0
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
        command: ["sh", "-c", "a=$(busctl --system tree org.bluez 2>/dev/null | grep -oE '/org/bluez/hci[0-9]+' | head -1);" + "echo \"adapter|$a\";" + "[ -z \"$a\" ] && exit 0;" + "echo \"powered|$(busctl --system get-property org.bluez \"$a\" org.bluez.Adapter1 Powered 2>/dev/null | awk '{print $2}')\";" + "busctl --system tree org.bluez 2>/dev/null | grep -oE \"$a/dev_[A-F0-9_]+\" | sort -u | while read dev; do" + "  paired=$(busctl --system get-property org.bluez \"$dev\" org.bluez.Device1 Paired 2>/dev/null | awk '{print $2}');" + "  [ \"$paired\" != 'true' ] && continue;" + "  conn=$(busctl --system get-property org.bluez \"$dev\" org.bluez.Device1 Connected 2>/dev/null | awk '{print $2}');" + "  name=$(busctl --system get-property org.bluez \"$dev\" org.bluez.Device1 Alias 2>/dev/null | sed -E 's/^s \"(.*)\"$/\\1/');" + "  echo \"dev|$dev|$conn|$name\";" + "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                const devs = [];
                let adapter = "";
                let powered = false;
                for (const raw of lines) {
                    const l = raw.trim();
                    if (!l)
                        continue;
                    if (l.startsWith("adapter|")) {
                        adapter = l.substring(8);
                    } else if (l.startsWith("powered|")) {
                        powered = l.substring(8) === "true";
                    } else if (l.startsWith("dev|")) {
                        const f = l.substring(4).split("|");
                        devs.push({
                            path: f[0],
                            connected: f[1] === "true",
                            name: f[2] || "Unknown"
                        });
                    }
                }
                devs.sort((a, b) => {
                    if (a.connected !== b.connected)
                        return b.connected - a.connected;
                    return a.name.localeCompare(b.name);
                });
                root.adapter = adapter;
                root.btEnabled = powered;
                root.devices = devs;
                if (root.busyPath && !devs.some(d => d.path === root.busyPath)) {
                    root.busyPath = "";
                }
            }
        }
    }

    Process {
        id: toggleProc
        property string target: "true"
        command: ["busctl", "--system", "set-property", "org.bluez", root.adapter, "org.bluez.Adapter1", "Powered", "b", toggleProc.target]
        onExited: fetchProc.running = true
    }

    Process {
        id: actionProc
        property string target: ""
        property string method: "Connect"
        command: ["busctl", "--system", "call", "org.bluez", actionProc.target, "org.bluez.Device1", actionProc.method]
        onExited: {
            root.busyPath = "";
            fetchProc.running = true;
        }
    }

    onShownChanged: {
        if (shown)
            fetchProc.running = true;
    }

    Timer {
        running: true
        interval: root.shown ? 4000 : 20000
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }
}
