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
        margins.bottom: 20
        implicitHeight: 72

        property string label: Quickshell.env("XHISPER_POPUP_TEXT") || ""
        property bool listening: label.indexOf("Listening") >= 0
        property color baseColor: listening ? "#2b2f36" : "#3a2f36"

        WlrLayershell.namespace: "quickshell-xhisper-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusiveZone: 0
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Item {
            anchors.centerIn: parent
            width: 56
            height: 56

            // Outer ring — sonar pulse outward.
            Rectangle {
                anchors.centerIn: parent
                width: 32
                height: 32
                radius: width / 2
                color: "transparent"
                border.color: root.baseColor
                border.width: 1.5

                NumberAnimation on scale {
                    loops: Animation.Infinite
                    running: true
                    from: 1.0; to: 1.7
                    duration: 1400
                    easing.type: Easing.OutQuad
                }
                NumberAnimation on opacity {
                    loops: Animation.Infinite
                    running: true
                    from: 0.55; to: 0.0
                    duration: 1400
                }
            }

            // Inner core — dark gradient circle that breathes gently.
            Rectangle {
                id: core
                anchors.centerIn: parent
                width: 22
                height: 22
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(root.baseColor, 1.6) }
                    GradientStop { position: 1.0; color: Qt.darker(root.baseColor, 1.3) }
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
