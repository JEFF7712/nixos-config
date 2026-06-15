import QtQuick
import Quickshell
import Quickshell.Io

InfoPopup {
    id: root
    title: "SYSTEM"

    property string cpuUsage: "—"
    property string ramUsage: "—"
    property string diskUsage: "—"
    property string hostName: "—"
    property string kernel: "—"
    property string uptime: "—"
    property string nixGen: ""

    function exec(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd])
        root.close()
    }

    InfoRow { label: "host";   value: root.hostName; themeFg: root.themeFg; active: root.shown }
    InfoRow { label: "kernel"; value: root.kernel;   themeFg: root.themeFg; active: root.shown }
    InfoRow { label: "uptime"; value: root.uptime;   themeFg: root.themeFg; active: root.shown }
    InfoRow { label: "gen";    value: root.nixGen;   themeFg: root.themeFg; active: root.shown; visible: root.nixGen !== "" }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    InfoRow { label: "cpu";  value: root.cpuUsage;  themeFg: root.themeFg; active: root.shown }
    InfoRow { label: "ram";  value: root.ramUsage;  themeFg: root.themeFg; active: root.shown }
    InfoRow { label: "disk"; value: root.diskUsage; themeFg: root.themeFg; active: root.shown }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    ActionRow {
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        icon: "󰌾"
        label: "lock"
        onActivated: root.exec("lock-screen")
    }
    ActionRow {
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        icon: "󰒲"
        label: "sleep"
        onActivated: root.exec("systemctl suspend")
    }
    ActionRow {
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        icon: "󰍃"
        label: "logout"
        onActivated: root.exec("niri msg action quit -s")
    }
    ActionRow {
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        icon: "󰜉"
        label: "restart"
        onActivated: root.exec("systemctl reboot")
    }
    ActionRow {
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        icon: "󰐥"
        label: "shutdown"
        onActivated: root.exec("systemctl poweroff")
    }

    Process {
        id: fetchProc
        command: ["sh", "-c",
            "echo \"host|$(hostnamectl hostname 2>/dev/null || hostname)\";" +
            "echo \"kernel|$(uname -r)\";" +
            "echo \"uptime|$(uptime -p 2>/dev/null | sed 's/^up //')\";" +
            "g=$(readlink /nix/var/nix/profiles/system 2>/dev/null | grep -o '[0-9]*' | head -1);" +
            "[ -n \"$g\" ] && echo \"gen|$g\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                for (const raw of lines) {
                    const l = raw.trim()
                    const idx = l.indexOf("|")
                    if (idx < 0) continue
                    const k = l.substring(0, idx)
                    const v = l.substring(idx + 1).trim()
                    if (k === "host") root.hostName = v || "—"
                    else if (k === "kernel") root.kernel = v || "—"
                    else if (k === "uptime") root.uptime = v || "—"
                    else if (k === "gen") root.nixGen = v
                }
            }
        }
    }

    onShownChanged: { if (shown) fetchProc.running = true }

    Timer {
        running: root.shown
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }
}
