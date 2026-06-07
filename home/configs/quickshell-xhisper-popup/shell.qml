// xhisper popup — small Siri-style ball at bottom-center, breathes and pulses
// while xhisper is recording / transcribing. Colour comes from
// XHISPER_POPUP_TEXT: "Listening" → cool blue, anything else → warm violet.
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    PanelWindow {
        id: root
        color: "transparent"

        anchors { bottom: true; left: true; right: true }
        margins.bottom: 50
        implicitHeight: 100

        property string label: Quickshell.env("XHISPER_POPUP_TEXT") || ""
        property bool listening: label.indexOf("Listening") >= 0
        property color baseColor: listening ? "#88c0d0" : "#b48ead"

        WlrLayershell.namespace: "quickshell-xhisper-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusiveZone: 0
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Item {
            anchors.centerIn: parent
            width: 80
            height: 80

            // Outer ring that pulses outward and fades — the "Siri" sonar wave.
            Rectangle {
                anchors.centerIn: parent
                width: 48
                height: 48
                radius: width / 2
                color: "transparent"
                border.color: root.baseColor
                border.width: 2

                ParallelAnimation on scale {
                    loops: Animation.Infinite
                    running: true
                    NumberAnimation { from: 1.0; to: 1.7; duration: 1400; easing.type: Easing.OutQuad }
                }
                NumberAnimation on opacity {
                    loops: Animation.Infinite
                    running: true
                    from: 0.55; to: 0.0
                    duration: 1400
                }
            }

            // Inner core: radial-style gradient circle that breathes gently.
            Rectangle {
                id: core
                anchors.centerIn: parent
                width: 36
                height: 36
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(root.baseColor, 1.5) }
                    GradientStop { position: 1.0; color: Qt.darker(root.baseColor, 1.2) }
                }

                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: true
                    NumberAnimation { from: 1.0; to: 1.12; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.12; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
