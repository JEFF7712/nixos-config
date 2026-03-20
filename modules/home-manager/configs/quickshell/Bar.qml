import Quickshell
import QtQuick
import QtQuick.Layouts
import "."
import "./islands"

// PanelWindow is re-exported via Quickshell (which default-imports Quickshell._Window)
PanelWindow {
    id: root

    signal powerRequested()

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 36
    exclusiveZone: 36
    color: "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        LeftIsland {
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        CenterIsland {
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        RightIsland {
            id: rightIsland
            Layout.alignment: Qt.AlignVCenter
            onPowerRequested: root.powerRequested()
        }
    }
}
