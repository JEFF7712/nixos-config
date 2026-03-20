import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Mpris
import ".."

Rectangle {
    id: root
    implicitHeight: 28
    radius: 14
    color: Theme.withAlpha(Theme.surface, 0.85)
    border.color: Theme.withAlpha(Theme.border, 0.3)
    border.width: 1
    implicitWidth: row.implicitWidth + 24

    signal volumeRequested()
    signal brightnessRequested()
    signal musicRequested()
    signal quickSettingsRequested()
    signal powerRequested()

    // Mpris: show first active player
    property var player: Mpris.players.length > 0 ? Mpris.players[0] : null
    property string musicTitle: player ? (player.trackTitle ?? "") : ""

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        // Music mini pill
        Text {
            visible: root.musicTitle !== ""
            text: "\uf001  " + (root.musicTitle.length > 20
                ? root.musicTitle.slice(0, 18) + "\u2026"
                : root.musicTitle)
            color: Theme.success
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
            MouseArea { anchors.fill: parent; onClicked: root.musicRequested() }
        }

        Rectangle {
            width: 1; height: 16; color: Theme.border; opacity: 0.4
            visible: root.musicTitle !== ""
        }

        // Volume
        Text {
            text: "\uf028"
            color: Theme.text
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
            MouseArea {
                anchors.fill: parent
                onClicked: root.volumeRequested()
                onWheel: event => {
                    const d = event.angleDelta.y > 0 ? 5 : -5
                    volWheel.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@",
                        (d > 0 ? "+" : "") + Math.abs(d) + "%"]
                    volWheel.running = true
                }
            }
        }

        // Brightness
        Text {
            text: "\uf185"
            color: Theme.text
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
            MouseArea {
                anchors.fill: parent
                onClicked: root.brightnessRequested()
                onWheel: event => {
                    const d = event.angleDelta.y > 0 ? 5 : -5
                    briWheel.command = ["brightnessctl", "set",
                        (d > 0 ? "+" : "") + Math.abs(d) + "%"]
                    briWheel.running = true
                }
            }
        }

        Rectangle { width: 1; height: 16; color: Theme.border; opacity: 0.4 }

        // Indicators / quick settings
        Text {
            text: "\uf1eb"
            color: Theme.text
            font.pixelSize: 12
            font.family: "JetBrainsMono Nerd Font"
            MouseArea { anchors.fill: parent; onClicked: root.quickSettingsRequested() }
        }

        Rectangle { width: 1; height: 16; color: Theme.border; opacity: 0.4 }

        // Power
        Text {
            text: "\uf011"
            color: Theme.error
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
            MouseArea { anchors.fill: parent; onClicked: root.powerRequested() }
        }
    }

    Process { id: volWheel; command: [] }
    Process { id: briWheel; command: [] }
}
