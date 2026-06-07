// xhisper popup — horizontal voice-memo style waveform at bottom-center.
// A fixed-count row of vertical bars; each bar's height tracks one historical
// amplitude sample. New samples push in on the right; old ones scroll left.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    PanelWindow {
        id: root
        color: "transparent"

        anchors { bottom: true; left: true; right: true }
        margins.bottom: 20
        implicitHeight: 56

        property string label: Quickshell.env("XHISPER_POPUP_TEXT") || ""
        property bool listening: label.indexOf("Listening") >= 0
        property color barColor: listening ? "#15181f" : "#231921"
        property real level: 0.0
        property int historySize: 32
        property var history: []

        Component.onCompleted: {
            const h = []
            for (let i = 0; i < historySize; i++) h.push(0.0)
            history = h
        }

        onLevelChanged: {
            if (!history.length) return
            const h = history.slice(1)
            h.push(root.level)
            history = h
        }

        WlrLayershell.namespace: "quickshell-xhisper-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusiveZone: 0
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Process {
            id: amplitude
            command: ["xhisper-amplitude-monitor"]
            running: root.listening
            stdout: SplitParser {
                onRead: line => {
                    const v = parseFloat(line)
                    if (!isNaN(v)) root.level = v
                }
            }
        }

        Row {
            id: waveRow
            anchors.centerIn: parent
            spacing: 2
            height: 32

            Repeater {
                model: root.historySize
                Rectangle {
                    required property int index
                    width: 2
                    radius: 1
                    color: root.barColor
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.max(2, (root.history[index] || 0) * waveRow.height * 1.6)
                    Behavior on height {
                        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }
}
