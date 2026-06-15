import QtQuick
import Quickshell.Io

InfoPopup {
    id: root
    title: "BATTERY"

    property string powerProfile: ""
    property string charge: "—"
    property string status_: "—"
    property string timeLeft: ""
    property string draw: "—"
    property string health: "—"
    property int chargeLimit: 100
    property bool thresholdWritable: false

    signal selectProfile(string name)

    readonly property var profileOptions: [
        { id: "power-saver", icon: "󰌪", label: "save" },
        { id: "balanced", icon: "󰾅", label: "balanced" },
        { id: "performance", icon: "󱐋", label: "perf" }
    ]

    InfoRow { label: "charge"; value: root.charge;       themeFg: root.themeFg; active: root.shown }
    InfoRow { label: "status"; value: root.status_;      themeFg: root.themeFg; active: root.shown }
    InfoRow { label: "time";   value: root.timeLeft;     themeFg: root.themeFg; active: root.shown; visible: root.timeLeft !== "" }
    InfoRow { label: "draw";   value: root.draw;         themeFg: root.themeFg; active: root.shown }
    InfoRow { label: "health"; value: root.health;       themeFg: root.themeFg; active: root.shown }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    Text {
        text: "PROFILE"
        color: root.themeAccent
        opacity: 0.55
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 8; letterSpacing: 1.4; weight: Font.Medium }
        topPadding: 2
    }

    Row {
        width: parent.width
        spacing: 4

        Repeater {
            model: root.profileOptions

            delegate: Rectangle {
                id: seg
                required property var modelData
                readonly property bool selected: root.powerProfile === modelData.id
                width: (parent.width - 8) / 3
                height: 30
                radius: 6
                color: selected
                    ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.85)
                    : segMouse.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.08)
                        : root.pillBg
                border.width: 1
                border.color: selected
                    ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.4)
                    : root.pillBorder
                Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: seg.modelData.icon
                        color: seg.selected ? root.themeRawBg : root.themeFg
                        opacity: seg.selected ? 1.0 : 0.75
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: seg.modelData.label
                        color: seg.selected ? root.themeRawBg : root.themeFg
                        opacity: seg.selected ? 0.9 : 0.55
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 8; weight: Font.Medium }
                    }
                }

                MouseArea {
                    id: segMouse
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
        visible: root.thresholdWritable
    }

    InfoToggle {
        label: "limit charge to 80%"
        checked: root.chargeLimit <= 80
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        dividerColor: root.dividerColor
        visible: root.thresholdWritable
        onToggled: {
            limitProc.target = (root.chargeLimit <= 80) ? "100" : "80"
            limitProc.running = true
        }
    }

    Text {
        width: parent.width
        text: "(rebuild for charge limit)"
        visible: !root.thresholdWritable && root.charge !== "—"
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.3)
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; italic: true }
        horizontalAlignment: Text.AlignHCenter
        topPadding: 4
    }

    Process {
        id: fetchProc
        command: ["sh", "-c",
            "dev=$(upower -e 2>/dev/null | grep -i BAT | head -1);" +
            "[ -z \"$dev\" ] && exit 0;" +
            "upower -i \"$dev\" | awk -F: '" +
            "/percentage:/{gsub(/^[ \\t]+/,\"\",$2); print \"charge|\"$2}" +
            "/state:/{gsub(/^[ \\t]+/,\"\",$2); print \"status|\"$2}" +
            "/time to empty:/{gsub(/^[ \\t]+/,\"\",$2); print \"time|\"$2}" +
            "/time to full:/{gsub(/^[ \\t]+/,\"\",$2); print \"time|\"$2}" +
            "/energy-rate:/{gsub(/^[ \\t]+/,\"\",$2); print \"draw|\"$2}" +
            "/energy-full:/{gsub(/^[ \\t]+/,\"\",$2); print \"efull|\"$2}" +
            "/energy-full-design:/{gsub(/^[ \\t]+/,\"\",$2); print \"edesign|\"$2}" +
            "';" +
            "thr=/sys/class/power_supply/BAT0/charge_control_end_threshold;" +
            "if [ -f \"$thr\" ]; then" +
            "  echo \"limit|$(cat $thr)\";" +
            "  if [ -w \"$thr\" ]; then echo writable\\|1; else echo writable\\|0; fi;" +
            "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                let charge = "—", status = "—", time = "", draw = "—"
                let eFull = NaN, eDesign = NaN, limit = 100
                let writable = false
                for (const raw of lines) {
                    const l = raw.trim()
                    const idx = l.indexOf("|")
                    if (idx < 0) continue
                    const k = l.substring(0, idx)
                    const v = l.substring(idx + 1).trim()
                    if (k === "charge") charge = v
                    else if (k === "status") status = v.replace(/-/g, " ")
                    else if (k === "time") time = v
                    else if (k === "draw") draw = v
                    else if (k === "efull") eFull = parseFloat(v)
                    else if (k === "edesign") eDesign = parseFloat(v)
                    else if (k === "limit") limit = parseInt(v) || 100
                    else if (k === "writable") writable = v === "1"
                }
                root.charge = charge
                root.status_ = status
                root.timeLeft = time
                root.draw = draw
                root.health = (!isNaN(eFull) && !isNaN(eDesign) && eDesign > 0)
                    ? Math.round((eFull / eDesign) * 100) + "%"
                    : "—"
                root.chargeLimit = limit
                root.thresholdWritable = writable
            }
        }
    }

    Process {
        id: limitProc
        property string target: "100"
        command: ["sh", "-c",
            "echo " + limitProc.target + " > /sys/class/power_supply/BAT0/charge_control_end_threshold"
        ]
        onExited: fetchProc.running = true
    }

    onShownChanged: { if (shown) fetchProc.running = true }

    Timer {
        running: true
        interval: root.shown ? 5000 : 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }
}
