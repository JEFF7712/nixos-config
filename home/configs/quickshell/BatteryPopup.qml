import QtQuick
import Quickshell.Io

InfoPopup {
    id: root
    title: "BATTERY"

    property string powerProfile: ""
    property string charge: "-"
    property string status_: "-"
    property string timeLeft: ""
    property string draw: "-"
    property string health: "-"
    property int chargeLimit: 100
    property bool thresholdWritable: false
    property bool idleInhibited: false
    readonly property var profileOptions: [
        {
            "id": "power-saver",
            "icon": "󰌪",
            "label": "save"
        },
        {
            "id": "balanced",
            "icon": "󰾅",
            "label": "balanced"
        },
        {
            "id": "performance",
            "icon": "󱐋",
            "label": "perf"
        }
    ]

    signal selectProfile(string name)

    function percent(value) {
        const parsed = parseInt(String(value).replace("%", ""));
        return isNaN(parsed) ? 0 : Math.max(0, Math.min(100, parsed));
    }

    function hasBattery() {
        return root.charge !== "-";
    }

    function statusLabel() {
        if (!root.hasBattery())
            return "battery unavailable";
        if (root.status_ === "-")
            return root.charge;
        return root.charge + " " + root.status_;
    }

    function statusMeta() {
        const parts = [];
        if (root.timeLeft !== "")
            parts.push(root.timeLeft);
        if (root.draw !== "-")
            parts.push(root.draw);
        return parts.join("  ");
    }

    function profileLabel() {
        if (root.powerProfile === "power-saver")
            return "power saver";
        if (root.powerProfile === "performance")
            return "performance";
        if (root.powerProfile === "balanced")
            return "balanced";
        return "profile unavailable";
    }

    Item {
        width: parent.width
        height: 38

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: root.statusLabel()
                color: root.themeFg
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 12
                    weight: Font.Medium
                }
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.statusMeta()
                color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.44)
                visible: text !== ""
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 9
                }
                elide: Text.ElideRight
            }
        }
    }

    MeterRow {
        label: "charge"
        value: root.charge
        amount: root.percent(root.charge)
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        pillBg: root.pillBg
    }

    MeterRow {
        label: "health"
        value: root.health
        amount: root.percent(root.health)
        visible: root.health !== "-"
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        pillBg: root.pillBg
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    InfoRow {
        label: "profile"
        value: root.profileLabel()
        themeFg: root.themeFg
        active: root.shown
    }

    Row {
        width: parent.width
        height: 28
        spacing: 6

        Repeater {
            model: root.profileOptions

            Item {
                required property var modelData

                width: (parent.width - 12) / 3
                height: parent.height

                readonly property bool selected: root.powerProfile === modelData.id

                Rectangle {
                    anchors.fill: parent
                    radius: root.flatMode ? 0 : 6
                    color: parent.selected ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.18) : profileMouse.pressed ? Qt.rgba(1, 1, 1, 0.08) : profileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : root.pillBg
                    border.width: 1
                    border.color: parent.selected ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.38) : root.pillBorder
                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: modelData.icon
                        color: parent.parent.selected ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.64)
                        font {
                            family: "JetBrainsMono Nerd Font"
                            pixelSize: 11
                        }
                    }

                    Text {
                        text: modelData.label
                        color: parent.parent.selected ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.74)
                        font {
                            family: "JetBrainsMono Nerd Font"
                            pixelSize: 9
                            weight: parent.parent.selected ? Font.Medium : Font.Normal
                        }
                    }
                }

                MouseArea {
                    id: profileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectProfile(modelData.id)
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    InfoToggle {
        label: root.idleInhibited ? "idle inhibit on" : "idle inhibit off"
        checked: root.idleInhibited
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        dividerColor: root.dividerColor
        onToggled: idleInhibitToggleProc.running = true
    }

    Rectangle {
        width: parent.width
        height: 1
        visible: root.thresholdWritable
        color: root.dividerColor
    }

    InfoToggle {
        label: root.chargeLimit >= 100 ? "charge limit off" : "charge limit " + root.chargeLimit + "%"
        checked: root.chargeLimit < 100
        visible: root.thresholdWritable
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        dividerColor: root.dividerColor
        onToggled: {
            limitProc.target = root.chargeLimit >= 100 ? 80 : 100;
            limitProc.running = true;
        }
    }

    Process {
        id: fetchProc
        command: ["sh", "-c", "dev=$(upower -e 2>/dev/null | grep -i BAT | head -1);" + "[ -z \"$dev\" ] && exit 0;" + "upower -i \"$dev\" | awk -F: '" + "/percentage:/{gsub(/^[ \\t]+/,\"\",$2); print \"charge|\"$2}" + "/state:/{gsub(/^[ \\t]+/,\"\",$2); print \"status|\"$2}" + "/time to empty:/{gsub(/^[ \\t]+/,\"\",$2); print \"time|\"$2}" + "/time to full:/{gsub(/^[ \\t]+/,\"\",$2); print \"time|\"$2}" + "/energy-rate:/{gsub(/^[ \\t]+/,\"\",$2); print \"draw|\"$2}" + "/energy-full:/{gsub(/^[ \\t]+/,\"\",$2); print \"efull|\"$2}" + "/energy-full-design:/{gsub(/^[ \\t]+/,\"\",$2); print \"edesign|\"$2}" + "';" + "thr=/sys/class/power_supply/BAT0/charge_control_end_threshold;" + "if [ -f \"$thr\" ]; then " + "echo \"limit|$(cat \"$thr\")\";" + "if [ -w \"$thr\" ]; then echo \"writable|1\"; else echo \"writable|0\"; fi;" + "fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let eFull = 0;
                let eDesign = 0;
                const lines = this.text.split("\n");
                for (const raw of lines) {
                    const line = raw.trim();
                    const idx = line.indexOf("|");
                    if (idx < 0)
                        continue;
                    const key = line.substring(0, idx);
                    const value = line.substring(idx + 1).trim();

                    if (key === "charge")
                        root.charge = value || "-";
                    else if (key === "status")
                        root.status_ = (value || "-").replace(/-/g, " ");
                    else if (key === "time")
                        root.timeLeft = value;
                    else if (key === "draw")
                        root.draw = value || "-";
                    else if (key === "efull")
                        eFull = parseFloat(value);
                    else if (key === "edesign")
                        eDesign = parseFloat(value);
                    else if (key === "limit")
                        root.chargeLimit = parseInt(value) || 100;
                    else if (key === "writable")
                        root.thresholdWritable = value === "1";
                }
                if (eFull > 0 && eDesign > 0)
                    root.health = Math.round(eFull * 100 / eDesign) + "%";
            }
        }
    }

    Process {
        id: limitProc
        property int target: 100
        command: ["sh", "-c", "echo " + limitProc.target + " > /sys/class/power_supply/BAT0/charge_control_end_threshold"]
        onRunningChanged: {
            if (!running)
                fetchProc.running = true;
        }
    }

    Process {
        id: idleInhibitToggleProc
        command: ["sh", "-c", "stasis toggle-inhibit >/dev/null 2>&1"]
        onExited: idleInhibitProbe.running = true
    }

    Process {
        id: idleInhibitProbe
        command: ["sh", "-c", "stasis info 2>/dev/null | awk -F': *' '/^Manual Pause/{print $2; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.idleInhibited = this.text.trim() === "yes";
            }
        }
    }

    onShownChanged: {
        if (shown) {
            fetchProc.running = true;
            idleInhibitProbe.running = true;
        }
    }

    Timer {
        running: true
        interval: root.shown ? 5000 : 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }

    Timer {
        running: true
        interval: root.shown ? 5000 : 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: idleInhibitProbe.running = true
    }

    component MeterRow: Item {
        id: rowRoot
        property string label: ""
        property string value: "-"
        property int amount: 0
        property color themeFg: "#ffffff"
        property color themeAccent: "#ffffff"
        property color pillBg: Qt.rgba(1, 1, 1, 0.05)

        width: parent.width
        height: 24

        Text {
            id: labelText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: rowRoot.label
            color: Qt.rgba(rowRoot.themeFg.r, rowRoot.themeFg.g, rowRoot.themeFg.b, 0.55)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
            }
        }

        Rectangle {
            anchors.left: labelText.right
            anchors.right: valueText.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 4
            radius: 2
            color: rowRoot.pillBg

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * Math.max(0, Math.min(100, rowRoot.amount)) / 100
                height: parent.height
                radius: parent.radius
                color: Qt.rgba(rowRoot.themeAccent.r, rowRoot.themeAccent.g, rowRoot.themeAccent.b, 0.72)
                Behavior on width {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Text {
            id: valueText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: rowRoot.value
            color: rowRoot.themeFg
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
                weight: Font.Medium
            }
        }
    }
}
