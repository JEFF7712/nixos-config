import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import ".."

PanelWindow {
    id: root

    property bool shown: false
    signal close()

    visible: shown && Mpris.players.length > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    focusable: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "bar-popup"

    property var player: Mpris.players.length > 0 ? Mpris.players[0] : null
    property string trackTitle:  player ? (player.trackTitle  ?? "Nothing playing") : "Nothing playing"
    property string trackArtist: player ? (player.trackArtist ?? "") : ""
    property bool   playing:     player ? (player.isPlaying   ?? false) : false

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card
        anchors.right: parent.right; anchors.rightMargin: 10
        y: 48
        width: 280; height: 120
        radius: 12
        color: Theme.withAlpha(Theme.surface, 0.97)
        border.color: Theme.withAlpha(Theme.border, 0.35); border.width: 1

        MouseArea { anchors.fill: parent }

        Column {
            anchors { fill: parent; margins: 14 }
            spacing: 6

            Text {
                width: parent.width
                text: root.trackTitle
                color: Theme.text
                font.pixelSize: 13; font.bold: true
                font.family: "JetBrainsMono Nerd Font"
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.trackArtist
                color: Theme.textSubtle
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
                elide: Text.ElideRight
            }

            RowLayout {
                width: parent.width

                Item { Layout.fillWidth: true }

                Text {
                    text: "\uf048"
                    color: root.player ? Theme.text : Theme.withAlpha(Theme.text, 0.4)
                    font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"
                    MouseArea { anchors.fill: parent; onClicked: if (root.player) root.player.previous() }
                }

                Item { width: 16 }

                Text {
                    text: root.playing ? "\uf04c" : "\uf04b"
                    color: root.player ? Theme.accent : Theme.withAlpha(Theme.accent, 0.4)
                    font.pixelSize: 22; font.family: "JetBrainsMono Nerd Font"
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!root.player) return
                            if (root.playing) root.player.pause()
                            else root.player.play()
                        }
                    }
                }

                Item { width: 16 }

                Text {
                    text: "\uf051"
                    color: root.player ? Theme.text : Theme.withAlpha(Theme.text, 0.4)
                    font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"
                    MouseArea { anchors.fill: parent; onClicked: if (root.player) root.player.next() }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
