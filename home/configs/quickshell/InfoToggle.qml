import QtQuick

Item {
    id: root
    property string label: ""
    property bool checked: false
    property color themeFg: "#ffffff"
    property color themeAccent: "#ffffff"
    property color themeRawBg: "#141414"
    property color dividerColor: Qt.rgba(1, 1, 1, 0.1)
    signal toggled

    width: parent.width
    height: 26

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.65)
        font {
            family: "JetBrainsMono Nerd Font"
            pixelSize: 10
        }
    }

    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 16
        radius: 8
        color: root.checked ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.85) : root.dividerColor
        border.width: 1
        border.color: root.checked ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.4) : root.dividerColor
        Behavior on color {
            ColorAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: knob
            width: 12
            height: 12
            radius: 6
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 2 : 2
            color: root.checked ? root.themeRawBg : root.themeFg
            Behavior on x {
                SpringAnimation {
                    spring: 4
                    damping: 0.55
                    mass: 0.6
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 220
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
        }
    }
}
