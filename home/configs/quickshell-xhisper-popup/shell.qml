// xhisper popup — bottom-center pill that shows whatever XHISPER_POPUP_TEXT
// is set to at quickshell launch. xhisper.sh kills the process to dismiss.
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    PanelWindow {
        id: root
        color: "transparent"

        anchors { bottom: true; left: true; right: true }
        margins.bottom: 80
        implicitHeight: 60

        WlrLayershell.namespace: "quickshell-xhisper-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusiveZone: 0
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: label.implicitWidth + 36
            implicitHeight: label.implicitHeight + 18
            radius: 14
            color: "#dd171b22"
            border.color: "#aa88c0d0"
            border.width: 1

            Text {
                id: label
                anchors.centerIn: parent
                text: Quickshell.env("XHISPER_POPUP_TEXT") || "🎤 xhisper"
                color: "#eceff4"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
            }
        }
    }
}
