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
    property bool popupAttachToBar: false
    property bool closing: false
    property int frozenHeight: 0
    readonly property int cardRadius: flatMode ? 0 : 15
    readonly property int contentHeight: outerColumn.implicitHeight + 28
    default property alias body: contentColumn.data

    function open() {
        closeTimer.stop();
        root.closing = false;
        root.frozenHeight = 0;
        root.shown = true;
    }
    function close() {
        if (root.popupAttachToBar && root.shown) {
            root.frozenHeight = Math.max(1, root.implicitHeight);
            root.shown = false;
            root.closing = true;
            closeTimer.restart();
        } else {
            root.shown = false;
            root.closing = false;
            root.frozenHeight = 0;
        }
    }
    function toggle() {
        if (root.shown)
            root.close();
        else
            root.open();
    }

    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    visible: shown || closing
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
    implicitHeight: root.closing ? root.frozenHeight : root.contentHeight
    exclusiveZone: -1
    color: "transparent"

    Timer {
        id: closeTimer
        interval: 260
        repeat: false
        onTriggered: {
            root.closing = false;
            root.frozenHeight = 0;
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    Item {
        anchors.fill: parent
        clip: root.popupAttachToBar

        Rectangle {
            id: card
            width: parent.width
            height: parent.height
            radius: root.cardRadius
            color: root.themeBg
            border.width: 1
            border.color: root.themeBorder
            y: root.popupAttachToBar && !root.shown ? -height : 0
            opacity: root.popupAttachToBar ? 1.0 : (root.shown ? 1.0 : 0.0)
            scale: root.popupAttachToBar ? 1.0 : (root.shown ? 1.0 : 0.96)
            transformOrigin: Item.TopRight
            Behavior on y {
                enabled: root.popupAttachToBar
                NumberAnimation {
                    duration: 210
                    easing.type: Easing.InOutCubic
                }
            }
            Behavior on opacity {
                enabled: !root.popupAttachToBar
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                enabled: !root.popupAttachToBar
                SpringAnimation {
                    spring: 3.5
                    damping: 0.55
                    mass: 0.7
                }
            }

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
}
