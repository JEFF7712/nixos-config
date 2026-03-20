import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

// Full-screen overlay — must be instantiated at ShellRoot level.
// PanelWindow with all four anchors and exclusiveZone: -1 acts as an overlay.
PanelWindow {
    id: root

    property bool showing: false
    visible: showing

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    focusable: true
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.65)
        focus: true

        Keys.onEscapePressed: root.showing = false

        MouseArea {
            anchors.fill: parent
            onClicked: root.showing = false
        }

        Column {
            anchors.centerIn: parent
            spacing: 12

            Repeater {
                model: [
                    { label: "Lock",     icon: "\uf023", cmd: ["loginctl", "lock-session"] },
                    { label: "Suspend",  icon: "\uf186", cmd: ["systemctl", "suspend"] },
                    { label: "Reboot",   icon: "\uf021", cmd: ["systemctl", "reboot"] },
                    { label: "Shutdown", icon: "\uf011", cmd: ["systemctl", "poweroff"] },
                    { label: "Logout",   icon: "\uf2f5", cmd: ["niri", "msg", "action", "quit", "--skip-confirmation"] }
                ]

                delegate: Rectangle {
                    required property var modelData
                    width: 160; height: 52; radius: 14
                    color: Theme.withAlpha(Theme.surface, 0.9)
                    border.color: Theme.border; border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        Text {
                            text: modelData.icon
                            color: Theme.text
                            font.pixelSize: 18
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Text {
                            text: modelData.label
                            color: Theme.text
                            font.pixelSize: 15
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            actionProc.command = modelData.cmd
                            actionProc.running = true
                            root.showing = false
                        }
                    }
                }
            }
        }
    }

    Process { id: actionProc; command: [] }
}
