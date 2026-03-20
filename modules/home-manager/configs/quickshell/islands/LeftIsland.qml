import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."

Rectangle {
    id: root
    height: 28
    radius: 14
    color: Qt.rgba(
        parseInt(Theme.surface.slice(1,3), 16) / 255,
        parseInt(Theme.surface.slice(3,5), 16) / 255,
        parseInt(Theme.surface.slice(5,7), 16) / 255,
        0.85
    )
    border.color: Qt.rgba(
        parseInt(Theme.border.slice(1,3), 16) / 255,
        parseInt(Theme.border.slice(3,5), 16) / 255,
        parseInt(Theme.border.slice(5,7), 16) / 255,
        0.2
    )
    border.width: 1
    implicitWidth: row.implicitWidth + 16

    property var workspaces: []

    // Poll every 500ms. niri also supports event-stream but polling is simpler here.
    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: niriQuery.running = true
    }

    // "niri msg -j workspaces" (flag is -j, not --json)
    Process {
        id: niriQuery
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: SplitParser {
            // SplitParser fires onRead for each line; full JSON arrives as one line
            onRead: data => {
                try {
                    const parsed = JSON.parse(data)
                    // Filter to the output this bar instance belongs to and sort by idx
                    root.workspaces = parsed.sort((a, b) => a.idx - b.idx)
                } catch(e) {
                    // partial line or empty – ignore
                }
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
                    : Qt.rgba(
                        parseInt(Theme.accent.slice(1,3), 16) / 255,
                        parseInt(Theme.accent.slice(3,5), 16) / 255,
                        parseInt(Theme.accent.slice(5,7), 16) / 255,
                        0.25
                      )

                Text {
                    anchors.centerIn: parent
                    text: modelData.idx
                    color: modelData.is_focused ? Theme.accentText : Theme.textSubtle
                    font.pixelSize: 11
                    font.bold: modelData.is_focused
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        switchProc.command = ["niri", "msg", "action", "focus-workspace",
                            String(modelData.idx)]
                        switchProc.running = true
                    }
                }
            }
        }
    }

    // Separate process instance for focus-workspace actions
    Process {
        id: switchProc
        command: []
    }
}
