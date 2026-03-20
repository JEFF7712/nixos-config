import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."

Rectangle {
    id: root
    signal closeRequested()
    signal titleChanged(string title)

    width: 280; height: 100; radius: 12
    color: Theme.surfaceVariant
    border.color: Theme.border; border.width: 1
    x: -200; y: 36

    property string trackTitle:  "Nothing playing"
    property string trackArtist: ""
    property bool playing: false
    property real progressPos: 0
    property real durationSec: 0

    Timer {
        interval: 2000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: metaQuery.running = true
    }

    Process {
        id: metaQuery
        command: ["bash", "-c",
            "playerctl metadata --format '{{title}}|{{artist}}|{{status}}|{{position}}|{{mpris:length}}' 2>/dev/null || echo '|||0|0'"]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split("|")
                root.trackTitle  = parts[0] || "Nothing playing"
                root.trackArtist = parts[1] || ""
                root.playing     = parts[2] === "Playing"
                const pos = parseInt(parts[3]) / 1000000
                const dur = parseInt(parts[4]) / 1000000
                root.durationSec = dur
                root.progressPos = dur > 0 ? pos / dur : 0
                root.titleChanged(root.playing ? root.trackTitle : "")
            }
        }
    }

    Column {
        anchors { fill: parent; margins: 12 }
        spacing: 6

        Text {
            width: parent.width
            text: root.trackTitle
            color: Theme.text
            font.pixelSize: 13; font.bold: true
            elide: Text.ElideRight
        }

        Text {
            text: root.trackArtist
            color: Theme.textSubtle
            font.pixelSize: 11
            elide: Text.ElideRight
            width: parent.width
        }

        Rectangle {
            width: parent.width; height: 3; radius: 2
            color: Theme.border
            Rectangle {
                width: parent.width * root.progressPos
                height: 3; radius: 2
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }

        RowLayout {
            width: parent.width
            spacing: 16
            Item { Layout.fillWidth: true }

            Repeater {
                model: [
                    { label: "⏮", cmd: "previous" },
                    { label: root.playing ? "⏸" : "▶", cmd: "play-pause" },
                    { label: "⏭", cmd: "next" }
                ]
                delegate: Text {
                    required property var modelData
                    text: modelData.label
                    color: Theme.accent
                    font.pixelSize: 16
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            ctrlProc.command = ["playerctl", modelData.cmd]
                            ctrlProc.running = true
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }
    }

    Process { id: ctrlProc; command: [] }

    MouseArea {
        parent: root.parent; anchors.fill: parent; z: -1
        onClicked: root.closeRequested()
    }
}
