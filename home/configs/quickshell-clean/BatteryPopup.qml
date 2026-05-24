import QtQuick
import Quickshell.Io

InfoPopup {
    id: root
    title: "SYSTEM"

    property string cpuUsage: "—"
    property string ramUsage: "—"
    property string powerProfile: ""
    property string charge: "—"
    property string status_: "—"
    property string timeLeft: ""
    property string draw: "—"
    property string health: "—"
    property int chargeLimit: 100
    property bool thresholdWritable: false

    InfoRow { label: "cpu"; value: root.cpuUsage; themeFg: root.themeFg; active: root.shown }
    InfoRow { label: "ram"; value: root.ramUsage; themeFg: root.themeFg; active: root.shown }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    InfoRow { label: "charge"; value: root.charge;       themeFg: root.themeFg; active: root.shown }
    InfoRow { label: "status"; value: root.status_;      themeFg: root.themeFg; active: root.shown }
    InfoRow { label: "time";   value: root.timeLeft;     themeFg: root.themeFg; active: root.shown; visible: root.timeLeft !== "" }
    InfoRow { label: "draw";   value: root.draw;         themeFg: root.themeFg; active: root.shown }
    InfoRow { label: "health"; value: root.health;       themeFg: root.themeFg; active: root.shown }
    InfoRow { label: "profile"; value: root.powerProfile; themeFg: root.themeFg; active: root.shown; visible: root.powerProfile !== "" }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
        visible: root.thresholdWritable
    }

    InfoToggle {
        label: "limit charge to 80%"
        checked: root.chargeLimit <= 80
        themeFg: root.themeFg
        themeAccent: root.themeAccent
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
