import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."

Rectangle {
    id: root
    signal closeRequested()

    width: 180; height: 110; radius: 12
    color: Theme.surfaceVariant
    border.color: Theme.border; border.width: 1
    x: -120; y: 36

    property string wifiSsid:   "…"
    property bool wifiConnected: false
    property int  batteryPct:   -1

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
            Text { text: root.wifiConnected ? "📶" : "📵"; font.pixelSize: 14 }
            Column {
                Text { text: root.wifiConnected ? "Wi-Fi" : "Offline"; color: Theme.text; font.pixelSize: 12; font.bold: true }
                Text { text: root.wifiSsid; color: Theme.textSubtle; font.pixelSize: 10 }
            }
        }

        Row {
            spacing: 8; visible: root.batteryPct >= 0
            Text {
                text: root.batteryPct >= 80 ? "🔋" : root.batteryPct >= 30 ? "🪫" : "🔴"
                font.pixelSize: 14
            }
            Text {
                text: "Battery " + root.batteryPct + "%"
                color: root.batteryPct < 20 ? Theme.error : Theme.text
                font.pixelSize: 12
            }
        }
    }

    MouseArea {
        parent: root.parent; anchors.fill: parent; z: -1
        onClicked: root.closeRequested()
    }
}
