import QtQuick

Item {
    id: root
    property string label: ""
    property string hint: ""
    property string icon: ""
    property bool active: false
    property bool busy: false
    property color themeFg: "#ffffff"
    property color themeAccent: "#ffffff"
    signal activated

    width: parent.width
    height: 26

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 6
        color: mouse.pressed ? Qt.rgba(1, 1, 1, 0.10) : mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
    }

    Text {
        id: iconText
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        visible: root.icon !== ""
        color: root.active ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.7)
        font {
            family: "JetBrainsMono Nerd Font"
            pixelSize: 12
        }
        opacity: root.busy ? 0.4 : 1.0
        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
    }

    Text {
        id: labelText
        anchors.left: iconText.visible ? iconText.right : parent.left
        anchors.leftMargin: iconText.visible ? 8 : 6
        anchors.right: hintText.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.active ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.85)
        font {
            family: "JetBrainsMono Nerd Font"
            pixelSize: 11
            weight: root.active ? Font.Medium : Font.Normal
        }
        elide: Text.ElideRight
    }

    Text {
        id: hintText
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.busy ? "…" : root.hint
        color: root.active ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.55)
        font {
            family: "JetBrainsMono Nerd Font"
            pixelSize: 10
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.busy ? Qt.ForbiddenCursor : Qt.PointingHandCursor
        onClicked: {
            if (!root.busy)
                root.activated();
        }
    }
}
