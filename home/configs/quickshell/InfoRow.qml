import QtQuick

Item {
    id: root
    property string label: ""
    property string value: ""
    property color themeFg: "#ffffff"
    property bool active: true

    width: parent.width
    height: 22

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.55)
        font {
            family: "JetBrainsMono Nerd Font"
            pixelSize: 10
        }
    }

    Item {
        id: valueClip
        anchors.left: labelText.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        clip: true

        readonly property bool overflows: valueText.implicitWidth > width
        readonly property real restX: width - valueText.implicitWidth
        readonly property int scrollMs: Math.max(1500, Math.round((valueText.implicitWidth - width) * 28))

        QtObject {
            id: scrollState
            property real x: valueClip.restX
        }

        Text {
            id: valueText
            anchors.verticalCenter: parent.verticalCenter
            text: root.value
            color: root.themeFg
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 11
                weight: Font.Medium
            }
            x: valueClip.overflows ? scrollState.x : valueClip.restX
        }

        SequentialAnimation {
            running: valueClip.overflows && root.active
            loops: Animation.Infinite

            PropertyAction {
                target: scrollState
                property: "x"
                value: valueClip.restX
            }
            PauseAnimation {
                duration: 1800
            }
            NumberAnimation {
                target: scrollState
                property: "x"
                to: 0
                duration: valueClip.scrollMs
                easing.type: Easing.InOutQuad
            }
            PauseAnimation {
                duration: 1800
            }
            NumberAnimation {
                target: scrollState
                property: "x"
                to: valueClip.restX
                duration: valueClip.scrollMs
                easing.type: Easing.InOutQuad
            }
        }
    }
}
