import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."

Rectangle {
    id: root
    width: 200; height: 110; radius: 12
    color: Theme.surfaceVariant
    border.color: Theme.border; border.width: 1

    property string wifiSsid:    "\u2026"
    property bool wifiConnected: false
    property int  batteryPct:    -1

    Timer {
        interval: 5000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: { wifiQuery.running = true; batQuery.running = true }
    }

    Process {
        id: wifiQuery
        command: ["bash", "-c", "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -1"]
        stdout: SplitParser {
            onRead: data => {
                root.wifiSsid = data.trim() || "Disconnected"
                root.wifiConnected = data.trim() !== ""
            }
        }
    }

    Process {
        id: batQuery
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1"]
        stdout: SplitParser { onRead: data => root.batteryPct = parseInt(data.trim()) || -1 }
    }

    Column {
        anchors { fill: parent; margins: 12 }
        spacing: 10

        Row {
            spacing: 8
            Text {
                text: root.wifiConnected ? "\uf1eb" : "\uf127"  // wifi / chain-broken
                color: root.wifiConnected ? Theme.accent : Theme.textSubtle
                font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
            }
            Column {
                Text {
                    text: root.wifiConnected ? "Wi-Fi" : "Offline"
                    color: Theme.text; font.pixelSize: 12; font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                }
                Text {
                    text: root.wifiSsid
                    color: Theme.textSubtle; font.pixelSize: 10
                    font.family: "JetBrainsMono Nerd Font"
                }
            }
        }

        Row {
            spacing: 8; visible: root.batteryPct >= 0
            Text {
                text: root.batteryPct >= 75 ? "\uf240"  // full
                    : root.batteryPct >= 50 ? "\uf241"  // 3/4
                    : root.batteryPct >= 25 ? "\uf242"  // 1/2
                    : root.batteryPct >= 10 ? "\uf243"  // 1/4
                    : "\uf244"                           // empty
                color: root.batteryPct < 20 ? Theme.error
                     : root.batteryPct < 40 ? Theme.warning
                     : Theme.text
                font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
            }
            Text {
                text: "Battery " + root.batteryPct + "%"
                color: root.batteryPct < 20 ? Theme.error : Theme.text
                font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
            }
        }
    }
}
