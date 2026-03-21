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

        property int volumeLevel: 50

        MouseArea { anchors.fill: parent }

        Timer {
            interval: 2000; running: root.shown; repeat: true; triggeredOnStart: true
            onTriggered: volQuery.running = true
        }

        Process {
            id: volQuery
            command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\\d+(?=%)' | head -1"]
            stdout: SplitParser { onRead: data => card.volumeLevel = parseInt(data.trim()) || card.volumeLevel }
        }

        Process { id: setVol; command: [] }

        Column {
            anchors { fill: parent; margins: 12 }
            spacing: 8

            Row {
                spacing: 8
                Text {
                    text: "\uf028"
                    color: Theme.accent; font.pixelSize: 14
                    font.family: "JetBrainsMono Nerd Font"
                }
                Text {
                    text: card.volumeLevel + "%"
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
                        width: parent.width * Math.max(0, Math.min(100, card.volumeLevel)) / 100
                        height: parent.height; radius: parent.radius
                        color: Theme.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse => {
                        card.volumeLevel = Math.max(0, Math.min(100, Math.round(mouse.x / width * 100)))
                        setVol.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", card.volumeLevel + "%"]
                        setVol.running = true
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        card.volumeLevel = Math.max(0, Math.min(100, Math.round(mouse.x / width * 100)))
                        setVol.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", card.volumeLevel + "%"]
                        setVol.running = true
                    }
                }
            }
        }
    }
}
