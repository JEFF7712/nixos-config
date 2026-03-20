import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

// Full-screen overlay — must be instantiated at ShellRoot level, not as a child Rectangle.
// PanelWindow with all four anchors and exclusiveZone: -1 acts as an overlay that sits
// above all other surfaces without reserving any exclusive edge space.
PanelWindow {
    id: root

    property bool showing: false
    visible: showing

    // Cover the full screen on whichever output this is assigned to
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1  // -1 = no edge reservation; overlay floats above everything

    // Accept keyboard input so Escape can dismiss the menu
    focusable: true
    // Transparent backing — the dim overlay is drawn inside by the Rectangle below
    color: "transparent"

    // Dismiss on Escape
    Keys.onEscapePressed: root.showing = false

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)

        // Click the backdrop to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: root.showing = false
        }

        Column {
            anchors.centerIn: parent
            spacing: 16

            Repeater {
                model: [
                    { label: "Lock",     icon: "\uD83D\uDD12", cmd: ["loginctl", "lock-session"] },
                    { label: "Suspend",  icon: "\uD83D\uDCA4", cmd: ["systemctl", "suspend"] },
                    { label: "Reboot",   icon: "\uD83D\uDD04", cmd: ["systemctl", "reboot"] },
                    { label: "Shutdown", icon: "\u23FB",       cmd: ["systemctl", "poweroff"] },
                    { label: "Logout",   icon: "\uD83D\uDEAA", cmd: ["niri", "msg", "action", "quit", "--skip-confirmation"] }
                ]

                delegate: Rectangle {
                    required property var modelData

                    width: 160; height: 52; radius: 14
                    color: Qt.rgba(
                        parseInt(Theme.surface.slice(1, 3), 16) / 255,
                        parseInt(Theme.surface.slice(3, 5), 16) / 255,
                        parseInt(Theme.surface.slice(5, 7), 16) / 255,
                        0.9
                    )
                    border.color: Theme.border; border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 12
                        Text { text: modelData.icon; font.pixelSize: 20 }
                        Text { text: modelData.label; color: Theme.text; font.pixelSize: 16 }
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
