import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import ".."

Rectangle {
    id: root
    width: 280; height: 110; radius: 12
    color: Theme.surfaceVariant
    border.color: Theme.border; border.width: 1

    property var player: Mpris.players.length > 0 ? Mpris.players[0] : null
    property string trackTitle:  player ? (player.trackTitle  ?? "Nothing playing") : "Nothing playing"
    property string trackArtist: player ? (player.trackArtist ?? "") : ""
    property bool   playing:     player ? (player.isPlaying   ?? false) : false

    Column {
        anchors { fill: parent; margins: 12 }
        spacing: 6

        Text {
            width: parent.width
            text: root.trackTitle
            color: Theme.text
            font.pixelSize: 12; font.bold: true
            font.family: "JetBrainsMono Nerd Font"
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.trackArtist
            color: Theme.textSubtle
            font.pixelSize: 10
            font.family: "JetBrainsMono Nerd Font"
            elide: Text.ElideRight
        }

        RowLayout {
            width: parent.width

            Item { Layout.fillWidth: true }

            Text {
                text: "\uf048"   // previous
                color: root.player ? Theme.text : Theme.withAlpha(Theme.text, 0.4)
                font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
                MouseArea { anchors.fill: parent; onClicked: if (root.player) root.player.previous() }
            }

            Text {
                text: root.playing ? "\uf04c" : "\uf04b"  // pause / play
                color: root.player ? Theme.accent : Theme.withAlpha(Theme.accent, 0.4)
                font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!root.player) return
                        if (root.playing) root.player.pause()
                        else root.player.play()
                    }
                }
            }

            Text {
                text: "\uf051"   // next
                color: root.player ? Theme.text : Theme.withAlpha(Theme.text, 0.4)
                font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
                MouseArea { anchors.fill: parent; onClicked: if (root.player) root.player.next() }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
