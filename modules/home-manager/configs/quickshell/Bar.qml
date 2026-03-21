import Quickshell
import QtQuick
import QtQuick.Layouts
import "."
import "./islands"

PanelWindow {
    id: root

    property string activePopup: ""

    anchors { top: true; left: true; right: true }
    implicitHeight: 40
    exclusiveZone: 40
    color: "transparent"

    // Left island: workspaces
    LeftIsland {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
    }

    // Center island: clock
    CenterIsland {
        anchors.centerIn: parent
        onCalendarRequested: root.activePopup = root.activePopup === "calendar" ? "" : "calendar"
    }

    // Right island: system controls
    RightIsland {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        onVolumeRequested:        root.activePopup = root.activePopup === "volume"        ? "" : "volume"
        onBrightnessRequested:    root.activePopup = root.activePopup === "brightness"   ? "" : "brightness"
        onMusicRequested:         root.activePopup = root.activePopup === "music"        ? "" : "music"
        onQuickSettingsRequested: root.activePopup = root.activePopup === "quickSettings" ? "" : "quickSettings"
        onPowerRequested:         root.activePopup = root.activePopup === "power"        ? "" : "power"
    }
}
