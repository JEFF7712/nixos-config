import Quickshell
import QtQuick
import QtQuick.Layouts
import "."
import "./islands"
import "./popups"

PanelWindow {
    id: root

    signal powerRequested()

    property string activePopup: ""

    readonly property int barH: 36
    readonly property int popupH: {
        switch (activePopup) {
            case "calendar":      return 220
            case "volume":        return 80
            case "brightness":    return 80
            case "music":         return 120
            case "quickSettings": return 120
            default:              return 0
        }
    }

    anchors { top: true; left: true; right: true }
    implicitHeight: barH + popupH
    exclusiveZone: barH
    color: "transparent"

    // Bar strip
    RowLayout {
        x: 10; y: 0; width: parent.width - 20; height: barH
        spacing: 8

        LeftIsland   { Layout.alignment: Qt.AlignVCenter }
        Item         { Layout.fillWidth: true }
        CenterIsland {
            Layout.alignment: Qt.AlignVCenter
            onCalendarRequested: root.activePopup = root.activePopup === "calendar" ? "" : "calendar"
        }
        Item         { Layout.fillWidth: true }
        RightIsland  {
            id: rightIsland
            Layout.alignment: Qt.AlignVCenter
            onVolumeRequested:        root.activePopup = root.activePopup === "volume"        ? "" : "volume"
            onBrightnessRequested:    root.activePopup = root.activePopup === "brightness"   ? "" : "brightness"
            onMusicRequested:         root.activePopup = root.activePopup === "music"        ? "" : "music"
            onQuickSettingsRequested: root.activePopup = root.activePopup === "quickSettings" ? "" : "quickSettings"
            onPowerRequested:         { root.activePopup = ""; root.powerRequested() }
        }
    }

    // Transparent click-outside dismiss (covers popup area below bar)
    MouseArea {
        x: 0; y: barH; width: parent.width; height: root.popupH
        visible: root.popupH > 0
        z: 0
        onClicked: root.activePopup = ""
    }

    // Popup content — positioned below bar strip, right-aligned (calendar centered)
    Item {
        x: 0; y: barH; width: parent.width; height: root.popupH

        CalendarPopup {
            visible: root.activePopup === "calendar"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
        }
        VolumePopup {
            visible: root.activePopup === "volume"
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.top: parent.top
        }
        BrightnessPopup {
            visible: root.activePopup === "brightness"
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.top: parent.top
        }
        MusicPopup {
            visible: root.activePopup === "music"
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.top: parent.top
        }
        QuickSettings {
            visible: root.activePopup === "quickSettings"
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.top: parent.top
        }
    }
}
