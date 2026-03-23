import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

PanelWindow {
    id: root

    property bool shown: false
    signal close()

    visible: shown
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    focusable: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "bar-popup"

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card
        anchors.right: parent.right; anchors.rightMargin: 10
        y: 48
        width: 200; height: 110
        radius: 12
        color: Theme.withAlpha(Theme.surface, 0.97)
        border.color: Theme.withAlpha(Theme.border, 0.35); border.width: 1

        property string wifiSsid:    "\u2026"
        property bool wifiConnected: false
        property int  batteryPct:    -1

        MouseArea { anchors.fill: parent }

        Timer {
            interval: 5000; running: root.shown; repeat: true; triggeredOnStart: true
            onTriggered: { wifiQuery.running = true; batQuery.running = true }
        }

        Process {
            id: wifiQuery
            command: ["bash", "-c", "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -1"]
            stdout: SplitParser {
                onRead: data => {
                    card.wifiSsid = data.trim() || "Disconnected"
                    card.wifiConnected = data.trim() !== ""
                }
            }
        }

        Process {
            id: batQuery
            command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1"]
            stdout: SplitParser { onRead: data => card.batteryPct = parseInt(data.trim()) || -1 }
        }

        Column {
            anchors { fill: parent; margins: 12 }
            spacing: 10

            Row {
                spacing: 8
                Text {
                    text: card.wifiConnected ? "\uf1eb" : "\uf127"
                    color: card.wifiConnected ? Theme.accent : Theme.textSubtle
                    font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    Text {
                        text: card.wifiConnected ? "Wi-Fi" : "Offline"
                        color: Theme.text; font.pixelSize: 12; font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: card.wifiSsid
                        color: Theme.textSubtle; font.pixelSize: 10
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }

            Row {
                spacing: 8; visible: card.batteryPct >= 0
                Text {
                    text: card.batteryPct >= 75 ? "\uf240"
                        : card.batteryPct >= 50 ? "\uf241"
                        : card.batteryPct >= 25 ? "\uf242"
                        : card.batteryPct >= 10 ? "\uf243"
                        : "\uf244"
                    color: card.batteryPct < 20 ? Theme.error
                         : card.batteryPct < 40 ? Theme.warning
                         : Theme.text
                    font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Battery " + card.batteryPct + "%"
                    color: card.batteryPct < 20 ? Theme.error : Theme.text
                    font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
