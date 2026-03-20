import QtQuick
import QtQuick.Controls
import Quickshell.Io
import ".."

Rectangle {
    id: root
    signal closeRequested()

    width: 200; height: 72; radius: 12
    color: Theme.surfaceVariant
    border.color: Theme.border; border.width: 1
    x: -100; y: 36

    property int brightnessLevel: 80
    property int maxBrightness: 100

    Timer {
        interval: 2000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: { briCurrent.running = true; briMax.running = true }
    }

    Process {
        id: briCurrent
        command: ["brightnessctl", "get"]
        stdout: SplitParser { onRead: data => root.brightnessLevel = parseInt(data.trim()) || 0 }
    }

    Process {
        id: briMax
        command: ["brightnessctl", "max"]
        stdout: SplitParser { onRead: data => root.maxBrightness = parseInt(data.trim()) || 100 }
    }

    readonly property int pct: root.maxBrightness > 0
        ? Math.round(root.brightnessLevel / root.maxBrightness * 100)
        : 0

    Column {
        anchors { fill: parent; margins: 12 }
        spacing: 8

        Row {
            spacing: 8
            Text { text: "☀"; color: Theme.text; font.pixelSize: 14 }
            Text { text: root.pct + "%"; color: Theme.textSubtle; font.pixelSize: 12 }
        }

        Slider {
            width: parent.width
            from: 0; to: root.maxBrightness; value: root.brightnessLevel; stepSize: 1
            onMoved: {
                setBri.command = ["brightnessctl", "set", String(Math.round(value))]
                setBri.running = true
                root.brightnessLevel = value
            }
        }
    }

    Process { id: setBri; command: [] }

    MouseArea {
        parent: root.parent; anchors.fill: parent; z: -1
        onClicked: root.closeRequested()
    }
}
