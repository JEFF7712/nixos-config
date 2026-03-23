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

    property string outputName: ""
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
                    const all = JSON.parse(data)
                    root.workspaces = all
                        .filter(w => root.outputName === "" || w.output === root.outputName)
                        .sort((a, b) => a.idx - b.idx)
                } catch(e) {}
            }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.workspaces
            delegate: Rectangle {
                required property var modelData
                width: modelData.is_focused ? 18 : 8
                height: 8
                radius: 4
                color: modelData.is_focused
                    ? Theme.accent
                    : Theme.withAlpha(Theme.accent, 0.35)

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
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
