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
        width: 210; height: 72
        radius: 12
        color: Theme.withAlpha(Theme.surface, 0.97)
        border.color: Theme.withAlpha(Theme.border, 0.35); border.width: 1

        property int brightnessLevel: 80
        property int maxBrightness: 100
        readonly property int pct: maxBrightness > 0
            ? Math.round(brightnessLevel / maxBrightness * 100) : 0

        MouseArea { anchors.fill: parent }

        Timer {
            interval: 2000; running: root.shown; repeat: true; triggeredOnStart: true
            onTriggered: { briCurrent.running = true; briMax.running = true }
        }

        Process {
            id: briCurrent
            command: ["brightnessctl", "get"]
            stdout: SplitParser { onRead: data => card.brightnessLevel = parseInt(data.trim()) || 0 }
        }

        Process {
            id: briMax
            command: ["brightnessctl", "max"]
            stdout: SplitParser { onRead: data => card.maxBrightness = parseInt(data.trim()) || 100 }
        }

        Process { id: setBri; command: [] }

        Column {
            anchors { fill: parent; margins: 12 }
            spacing: 8

            Row {
                spacing: 8
                Text {
                    text: "\uf185"
                    color: Theme.accent; font.pixelSize: 14
                    font.family: "JetBrainsMono Nerd Font"
                }
                Text {
                    text: card.pct + "%"
                    color: Theme.text; font.pixelSize: 12
                    font.family: "JetBrainsMono Nerd Font"
                }
            }

            Item {
                width: parent.width; height: 20

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 4; radius: 2
                    color: Theme.withAlpha(Theme.border, 0.4)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, card.pct)) / 100
                        height: parent.height; radius: parent.radius
                        color: Theme.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse => {
                        var val = Math.round(mouse.x / width * card.maxBrightness)
                        card.brightnessLevel = val
                        setBri.command = ["brightnessctl", "set", String(val)]
                        setBri.running = true
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        var val = Math.round(mouse.x / width * card.maxBrightness)
                        card.brightnessLevel = val
                        setBri.command = ["brightnessctl", "set", String(val)]
                        setBri.running = true
                    }
                }
            }
        }
    }
}
