import QtQuick
import QtQuick.Effects
import Quickshell
import "services" as Services

InfoPopup {
    id: root
    title: "MEDIA"
    popupPosition: "center"
    implicitWidth: 330

    required property Services.MediaService mediaService
    required property Services.CavaService cavaService

    property bool seeking: false
    property real seekPosition: 0

    readonly property real displayedPosition: root.seeking ? root.seekPosition : root.mediaService.positionSeconds
    readonly property real seekFrac: root.mediaService.lengthSeconds > 0 ? Math.max(0, Math.min(1, root.displayedPosition / root.mediaService.lengthSeconds)) : 0

    function fmt(sec) {
        if (!sec || sec < 0)
            return "0:00";
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" + s : s);
    }
    onShownChanged: {
        if (!root.shown)
            root.seeking = false;
    }

    background: [
        Item {
            id: bgRoot
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: bgMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Image {
                id: bgArtSrc
                anchors.fill: parent
                source: root.mediaService.artUrl
                fillMode: Image.PreserveAspectCrop
                visible: false
                asynchronous: true
                cache: true
            }
            MultiEffect {
                anchors.fill: parent
                source: bgArtSrc
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1.0
                blurMax: 48
                brightness: -0.05
                saturation: 0.1
                visible: bgArtSrc.status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent
                color: root.themeBg
                opacity: bgArtSrc.status === Image.Ready ? 0.82 : 1.0
            }
        },
        Item {
            id: bgMask
            anchors.fill: parent
            layer.enabled: true
            visible: false
            Rectangle {
                anchors.fill: parent
                radius: root.cardRadius
                color: "black"
            }
        }
    ]

    Item {
        width: parent.width
        height: 128

        Rectangle {
            id: coverFrame
            anchors.centerIn: parent
            width: 120
            height: 120
            radius: 12
            color: Qt.rgba(root.pillBg.r, root.pillBg.g, root.pillBg.b, 0.6)
            border.width: 1
            border.color: root.pillBorder
            clip: true

            Image {
                id: cover
                anchors.fill: parent
                anchors.margins: 1
                source: root.mediaService.artUrl
                fillMode: Image.PreserveAspectCrop
                visible: cover.status === Image.Ready
                asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                text: "󰎈"
                color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.3)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 40
                }
                visible: cover.status !== Image.Ready
            }
        }
    }

    Column {
        width: parent.width
        spacing: 2

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.mediaService.title || "—"
            color: root.themeFg
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 13
                weight: Font.Bold
            }
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.mediaService.artist
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.7)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 11
            }
            elide: Text.ElideRight
            visible: root.mediaService.artist !== ""
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.mediaService.album
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.42)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 9
                italic: true
            }
            elide: Text.ElideRight
            visible: root.mediaService.album !== ""
        }
    }

    Item {
        width: parent.width
        height: 22
        visible: root.mediaService.playing && root.cavaService.values.length > 0

        Row {
            anchors.centerIn: parent
            height: 20
            spacing: 3
            Repeater {
                model: root.cavaService.values
                delegate: Rectangle {
                    width: 3
                    radius: 1.5
                    anchors.bottom: parent.bottom
                    height: Math.max(2, Math.min(20, (modelData / 100) * 20))
                    color: root.themeAccent
                    Behavior on height {
                        NumberAnimation {
                            duration: 80
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    Item {
        width: parent.width
        height: 22

        Text {
            id: posLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.fmt(root.displayedPosition)
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.7)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 9
            }
        }
        Text {
            id: lenLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.fmt(root.mediaService.lengthSeconds)
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.7)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 9
            }
        }
        Item {
            id: seekTrack
            anchors.left: posLabel.right
            anchors.right: lenLabel.left
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 6

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.15)
            }
            Rectangle {
                id: seekFill
                height: parent.height
                width: parent.width * root.seekFrac
                radius: 3
                color: root.themeAccent
            }
            Rectangle {
                visible: root.mediaService.canSeek
                width: 10
                height: 10
                radius: 5
                color: root.themeAccent
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, seekFill.width - width / 2))
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                enabled: root.mediaService.canSeek
                cursorShape: root.mediaService.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                function seekTo(mx) {
                    const frac = Math.max(0, Math.min(1, mx / seekTrack.width));
                    root.seekPosition = frac * root.mediaService.lengthSeconds;
                }
                onPressed: mouse => {
                    root.seeking = true;
                    seekTo(mouse.x);
                }
                onPositionChanged: mouse => {
                    if (root.seeking)
                        seekTo(mouse.x);
                }
                onReleased: {
                    root.mediaService.seek(root.seekPosition);
                    root.seeking = false;
                }
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        CtrlBtn {
            icon: "󰒞"
            active: root.mediaService.shuffleEnabled
            onActivated: root.mediaService.toggleShuffle()
        }
        CtrlBtn {
            icon: "󰒮"
            onActivated: root.mediaService.previous()
        }
        CtrlBtn {
            icon: root.mediaService.playing ? "󰏤" : "󰐊"
            primary: true
            onActivated: root.mediaService.togglePlaying()
        }
        CtrlBtn {
            icon: "󰒭"
            onActivated: root.mediaService.next()
        }
        CtrlBtn {
            icon: root.mediaService.loopMode === "Track" ? "󰑘" : "󰑖"
            active: root.mediaService.loopMode !== "None"
            onActivated: root.mediaService.cycleLoop()
        }
    }

    Item {
        width: parent.width
        height: 22

        Text {
            id: volIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.mediaService.effectiveVolume <= 0 ? "󰖁" : root.mediaService.effectiveVolume < 0.5 ? "󰖀" : "󰕾"
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.75)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 13
            }
        }
        Text {
            id: volTag
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.mediaService.volumeIsPlayer ? "APP" : "SYS"
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.35)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 7
                weight: Font.Bold
                letterSpacing: 0.5
            }
        }
        Item {
            id: volTrack
            anchors.left: volIcon.right
            anchors.right: volTag.left
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 6

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.15)
            }
            Rectangle {
                id: volFill
                height: parent.height
                width: parent.width * root.mediaService.effectiveVolume
                radius: 3
                color: root.themeAccent
            }
            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: root.themeAccent
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, volFill.width - width / 2))
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                function setFromX(mx) {
                    root.mediaService.setEffectiveVolume(mx / volTrack.width);
                }
                onPressed: mouse => setFromX(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        setFromX(mouse.x);
                }
            }
        }
    }

    component CtrlBtn: Item {
        id: btn
        property string icon
        property bool primary: false
        property bool active: false
        signal activated
        width: primary ? 38 : 30
        height: primary ? 38 : 30

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: btnMouse.pressed ? Qt.rgba(1, 1, 1, 0.18) : btnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : (btn.primary || btn.active) ? root.pillBg : "transparent"
            border.width: 1
            border.color: (btn.active || btnMouse.containsMouse) ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.5) : root.pillBorder
            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 160
                }
            }
            scale: btnMouse.pressed ? 0.92 : 1.0
            Behavior on scale {
                SpringAnimation {
                    spring: 4
                    damping: 0.55
                    mass: 0.6
                }
            }
        }
        Text {
            anchors.centerIn: parent
            text: btn.icon
            color: (btn.active || btnMouse.containsMouse) ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.85)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: btn.primary ? 19 : 15
            }
            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.activated()
        }
    }
}
