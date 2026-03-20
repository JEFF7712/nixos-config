import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."

Rectangle {
    id: root
    implicitHeight: 28
    radius: 14
    color: Theme.withAlpha(Theme.surface, 0.85)
    border.color: Theme.withAlpha(Theme.border, 0.3)
    border.width: 1
    implicitWidth: row.implicitWidth + 16

    property var workspaces: []

    Timer {
        interval: 500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: niriQuery.running = true
    }

    Process {
        id: niriQuery
        command: ["/run/current-system/sw/bin/niri", "msg", "-j", "workspaces"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.workspaces = JSON.parse(data).sort((a, b) => a.idx - b.idx)
                } catch(e) {}
            }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.workspaces
            delegate: Rectangle {
                required property var modelData
                width: 22; height: 22; radius: 6
                color: modelData.is_focused
                    ? Theme.accent
                    : Theme.withAlpha(Theme.accent, 0.25)

                Text {
                    anchors.centerIn: parent
                    text: modelData.idx
                    color: modelData.is_focused ? Theme.accentText : Theme.textSubtle
                    font.pixelSize: 11
                    font.bold: modelData.is_focused
                    font.family: "JetBrainsMono Nerd Font"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        switchProc.command = ["/run/current-system/sw/bin/niri", "msg",
                            "action", "focus-workspace", String(modelData.idx)]
                        switchProc.running = true
                    }
                }
            }
        }
    }

    Process { id: switchProc; command: [] }
}
