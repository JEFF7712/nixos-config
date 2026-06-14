import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool shown: false
    property string title: ""
    property string popupPosition: "right"
    property int topMargin: 64
    property color themeFg: "#ffffff"
    property color themeBg: "#662a2a2a"
    property color themeAccent: "#ffffff"
    property color themeRawBg: "#141414"
    property color themeBorder: Qt.rgba(1, 1, 1, 0.24)
    property color innerHighlight: Qt.rgba(1, 1, 1, 0.06)
    property color dividerColor: Qt.rgba(1, 1, 1, 0.1)
    property color pillBg: Qt.rgba(1, 1, 1, 0.05)
    property color pillBorder: Qt.rgba(1, 1, 1, 0.1)
    property bool flatMode: false
    readonly property int cardRadius: flatMode ? 0 : 15
    default property alias body: contentColumn.data

    function open() { root.shown = true }
    function close() { root.shown = false }
    function toggle() { root.shown = !root.shown }

    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    visible: shown
    anchors {
        top: true
        right: root.popupPosition === "right"
        left: root.popupPosition === "left"
    }
    margins {
        top: root.topMargin
        right: root.popupPosition === "right" ? 10 : 0
        left: root.popupPosition === "left" ? 10 : 0
    }
    implicitWidth: 300
    implicitHeight: outerColumn.implicitHeight + 28
    exclusiveZone: -1
    color: "transparent"

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: root.cardRadius
        color: root.themeBg
        border.width: 1
        border.color: root.themeBorder
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.96
        transformOrigin: Item.TopRight
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.55; mass: 0.7 } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            color: root.innerHighlight
        }

        Column {
            id: outerColumn
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6

            Text {
                text: root.title
                color: root.themeAccent
                opacity: 0.7
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 9
                    letterSpacing: 1.6
                    weight: Font.Medium
                }
            }

            Rectangle {
                width: outerColumn.width
                height: 1
                color: root.dividerColor
            }

            Column {
                id: contentColumn
                width: outerColumn.width
                spacing: 4
            }
        }
    }
}
