// xhisper popup — flat dark dot at bottom-center that pulses with the user's
// voice. Reads normalised amplitude (0–1) on stdout of xhisper-amplitude-monitor.
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
        property color dotColor: listening ? "#2b2f36" : "#3a2f36"
        property real level: 0.0

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

        Rectangle {
            id: core
            anchors.centerIn: parent
            width: 22
            height: 22
            radius: width / 2
            color: root.dotColor

            scale: 1.0 + root.level * 0.7
            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
            }
        }
    }
}
