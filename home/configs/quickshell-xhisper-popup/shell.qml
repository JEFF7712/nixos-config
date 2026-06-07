// xhisper popup — static dark core at bottom-center; loud syllables emit
// expanding rings that fade outward (sonar-ping behaviour).
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
        implicitHeight: 110

        property string label: Quickshell.env("XHISPER_POPUP_TEXT") || ""
        property bool listening: label.indexOf("Listening") >= 0
        property color dotColor: listening ? "#15181f" : "#231921"
        property real level: 0.0
        property real lastBurstAt: 0
        property real threshold: 0.18

        property real burstScale: 1.0
        property real burstOpacity: 0.0

        onLevelChanged: {
            const now = Date.now()
            if (root.listening && level > root.threshold && (now - root.lastBurstAt) > 320) {
                root.lastBurstAt = now
                burst.restart()
            }
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

        SequentialAnimation {
            id: burst
            PropertyAction { target: root; property: "burstScale"; value: 1.0 }
            PropertyAction { target: root; property: "burstOpacity"; value: 0.65 }
            ParallelAnimation {
                NumberAnimation { target: root; property: "burstScale"; to: 3.2; duration: 900; easing.type: Easing.OutCubic }
                NumberAnimation { target: root; property: "burstOpacity"; to: 0.0; duration: 900; easing.type: Easing.OutQuad }
            }
        }

        Item {
            anchors.centerIn: parent
            width: 110
            height: 110

            // Expanding burst ring — triggered by amplitude > threshold.
            Rectangle {
                anchors.centerIn: parent
                width: 32
                height: 32
                radius: width / 2
                color: "transparent"
                border.color: "#ffffff"
                border.width: 1.5
                scale: root.burstScale
                opacity: root.burstOpacity
            }

            // Static dark core.
            Rectangle {
                anchors.centerIn: parent
                width: 28
                height: 28
                radius: width / 2
                color: root.dotColor
            }
        }
    }
}
