// xhisper popup — dark static dot at bottom-center with a soft light halo
// behind it that brightens and expands with the user's voice amplitude.
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
        implicitHeight: 96

        property string label: Quickshell.env("XHISPER_POPUP_TEXT") || ""
        property bool listening: label.indexOf("Listening") >= 0
        property color dotColor: listening ? "#15181f" : "#231921"
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

        Item {
            anchors.centerIn: parent
            width: 96
            height: 96

            // Halo — behind the dot. Diameter and opacity grow with amplitude
            // so loud syllables emit a brighter, larger glow.
            Rectangle {
                anchors.centerIn: parent
                width: 36 + root.level * 50
                height: 36 + root.level * 50
                radius: width / 2
                color: "#ffffff"
                opacity: root.level * 0.35
                Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            }

            // Core dot — flat, dark, static.
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
