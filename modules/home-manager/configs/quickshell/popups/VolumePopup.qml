import QtQuick
import QtQuick.Controls
import Quickshell.Io
import ".."

Rectangle {
    id: root
    width: 200; height: 72; radius: 12
    color: Theme.surfaceVariant
    border.color: Theme.border; border.width: 1

    property int volumeLevel: 50

    Timer {
        interval: 2000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: volQuery.running = true
    }

    Process {
        id: volQuery
        command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\\d+(?=%)' | head -1"]
        stdout: SplitParser {
            onRead: data => root.volumeLevel = parseInt(data.trim()) || root.volumeLevel
        }
    }

    Column {
        anchors { fill: parent; margins: 12 }
        spacing: 8

        Row {
            spacing: 8
            Text { text: "\uf028"; color: Theme.text; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font" }
            Text { text: root.volumeLevel + "%"; color: Theme.textSubtle; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
        }

        Slider {
            width: parent.width
            from: 0; to: 100; value: root.volumeLevel; stepSize: 1
            onMoved: {
                setVol.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", value + "%"]
                setVol.running = true
                root.volumeLevel = value
            }
        }
    }

    Process { id: setVol; command: [] }
}
