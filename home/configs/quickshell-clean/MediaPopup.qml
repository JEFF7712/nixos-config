import QtQuick
import Quickshell

InfoPopup {
    id: root
    title: "MEDIA"

    property string status: ""
    property string track: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""

    function exec(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    Item {
        width: parent.width
        height: 76

        Rectangle {
            id: coverFrame
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 70
            height: 70
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)
            clip: true

            Image {
                id: cover
                anchors.fill: parent
                anchors.margins: 1
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                asynchronous: true
            }

            Text {
                anchors.centerIn: parent
                text: "󰎈"
                color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.3)
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 28 }
                visible: cover.status !== Image.Ready
            }
        }

        Column {
            anchors.left: coverFrame.right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            spacing: 4

            Text {
                width: parent.width
                text: root.track || "—"
                color: root.themeFg
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 11; weight: Font.Medium }
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.artist
                color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.65)
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                elide: Text.ElideRight
                visible: root.artist !== ""
            }

            Text {
                width: parent.width
                text: root.album
                color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.4)
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; italic: true }
                elide: Text.ElideRight
                visible: root.album !== ""
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        component CtrlBtn: Item {
            id: btn
            property string icon
            property bool primary: false
            signal activated()
            width: primary ? 36 : 28
            height: primary ? 36 : 28

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: btnMouse.pressed
                    ? Qt.rgba(1, 1, 1, 0.18)
                    : btnMouse.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.10)
                        : btn.primary ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                border.width: 1
                border.color: btnMouse.containsMouse
                    ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.5)
                    : btn.primary ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }
                scale: btnMouse.pressed ? 0.92 : 1.0
                Behavior on scale { SpringAnimation { spring: 4; damping: 0.55; mass: 0.6 } }
            }

            Text {
                anchors.centerIn: parent
                text: btn.icon
                color: btnMouse.containsMouse
                    ? root.themeAccent
                    : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.85)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: btn.primary ? 18 : 14
                }
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            MouseArea {
                id: btnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: btn.activated()
            }
        }

        CtrlBtn {
            icon: "󰒮"
            onActivated: root.exec("playerctl previous")
        }
        CtrlBtn {
            icon: root.status === "Playing" ? "󰏤" : "󰐊"
            primary: true
            onActivated: root.exec("playerctl play-pause")
        }
        CtrlBtn {
            icon: "󰒭"
            onActivated: root.exec("playerctl next")
        }
    }
}
