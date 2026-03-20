import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."
import "../popups"

Rectangle {
    id: root
    height: 28
    radius: 14
    color: Qt.rgba(
        parseInt(Theme.surface.slice(1,3), 16) / 255,
        parseInt(Theme.surface.slice(3,5), 16) / 255,
        parseInt(Theme.surface.slice(5,7), 16) / 255,
        0.85
    )
    border.color: Qt.rgba(
        parseInt(Theme.border.slice(1,3), 16) / 255,
        parseInt(Theme.border.slice(3,5), 16) / 255,
        parseInt(Theme.border.slice(5,7), 16) / 255,
        0.2
    )
    border.width: 1
    implicitWidth: row.implicitWidth + 24

    // PowerMenu cannot be a child of a Rectangle (it needs to be a PopupWindow
    // at the ShellRoot/Bar level). Signal bubbles up to Bar.qml instead.
    signal powerRequested()

    // Popup visibility flags — wired to actual popup components in Tasks 16-19
    property bool musicVisible:         false
    property bool volumeVisible:        false
    property bool brightnessVisible:    false
    property bool quickSettingsVisible: false

    property string musicTitle: ""

    function closeAll() {
        musicVisible        = false
        volumeVisible       = false
        brightnessVisible   = false
        quickSettingsVisible = false
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        // Music pill — hidden when no track is playing
        Text {
            visible: root.musicTitle !== ""
            text: "♪ " + (root.musicTitle.length > 20
                ? root.musicTitle.slice(0, 18) + "…"
                : root.musicTitle)
            color: Theme.success
            font.pixelSize: 11
            MouseArea {
                anchors.fill: parent
                onClicked: { root.closeAll(); root.musicVisible = true }
            }
        }

        Rectangle {
            width: 1; height: 16
            color: Theme.border; opacity: 0.4
            visible: root.musicTitle !== ""
        }

        // Volume icon
        Text {
            text: "🔊"
            font.pixelSize: 13
            MouseArea {
                anchors.fill: parent
                onClicked: { root.closeAll(); root.volumeVisible = !root.volumeVisible }
                onWheel: event => {
                    const delta = event.angleDelta.y > 0 ? 5 : -5
                    volumeProc.command = [
                        "pactl", "set-sink-volume", "@DEFAULT_SINK@",
                        (delta > 0 ? "+" : "") + Math.abs(delta) + "%"
                    ]
                    volumeProc.running = true
                }
            }
        }

        // Brightness icon
        Text {
            text: "☀"
            font.pixelSize: 13
            MouseArea {
                anchors.fill: parent
                onClicked: { root.closeAll(); root.brightnessVisible = !root.brightnessVisible }
                onWheel: event => {
                    const delta = event.angleDelta.y > 0 ? 5 : -5
                    brightnessProc.command = [
                        "brightnessctl", "set",
                        (delta > 0 ? "+" : "") + Math.abs(delta) + "%"
                    ]
                    brightnessProc.running = true
                }
            }
        }

        Rectangle { width: 1; height: 16; color: Theme.border; opacity: 0.4 }

        // Network / quick settings icon
        Text {
            text: "📶"
            font.pixelSize: 12
            MouseArea {
                anchors.fill: parent
                onClicked: { root.closeAll(); root.quickSettingsVisible = !root.quickSettingsVisible }
            }
        }

        Rectangle { width: 1; height: 16; color: Theme.border; opacity: 0.4 }

        // Power button
        Text {
            text: "⏻"
            color: Theme.error
            font.pixelSize: 13
            MouseArea {
                anchors.fill: parent
                onClicked: { root.closeAll(); root.powerRequested() }
            }
        }
    }

    // Scroll-wheel volume / brightness processes
    Process { id: volumeProc;     command: [] }
    Process { id: brightnessProc; command: [] }

    // Popups — plain Rectangles, safe as children
    VolumePopup {
        visible: root.volumeVisible
        onCloseRequested: root.volumeVisible = false
    }
    BrightnessPopup {
        visible: root.brightnessVisible
        onCloseRequested: root.brightnessVisible = false
    }
    MusicPopup {
        visible: root.musicVisible
        onCloseRequested: root.musicVisible = false
        onTitleChanged: title => root.musicTitle = title
    }
    QuickSettings {
        visible: root.quickSettingsVisible
        onCloseRequested: root.quickSettingsVisible = false
    }
}
