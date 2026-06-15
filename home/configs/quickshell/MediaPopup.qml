import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

InfoPopup {
    id: root
    title: "MEDIA"
    popupPosition: "center"
    implicitWidth: 330

    property string status: ""
    property string track: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""
    property var cavaValues: []

    property real positionSec: 0
    property real lengthSec: 0
    property bool shuffleOn: false
    property string loopMode: "None"
    property real volume: 0
    property bool volumeIsPlayer: false
    property bool seeking: false

    readonly property bool playing: root.status === "Playing"
    readonly property bool canSeek: root.lengthSec > 0
    readonly property real seekFrac: root.lengthSec > 0 ? Math.max(0, Math.min(1, root.positionSec / root.lengthSec)) : 0

    function exec(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }
    function fmt(sec) {
        if (!sec || sec < 0)
            return "0:00";
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" + s : s);
    }
    function refresh() {
        statePoll.running = true;
        posProc.running = true;
    }
    function setVolume(frac) {
        const v = Math.max(0, Math.min(1, frac));
        root.volume = v;
        if (root.volumeIsPlayer)
            root.exec("playerctl volume " + v.toFixed(2));
        else
            root.exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v.toFixed(2));
    }
    function cycleLoop() {
        const next = root.loopMode === "None" ? "Playlist" : root.loopMode === "Playlist" ? "Track" : "None";
        root.loopMode = next;
        root.exec("playerctl loop " + next);
        refreshTimer.restart();
    }

    onShownChanged: {
        if (root.shown)
            root.refresh();
        else
            root.seeking = false;
    }

    Process {
        id: posProc
        command: ["sh", "-c", "playerctl position 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(this.text.trim());
                if (!isNaN(v) && !root.seeking)
                    root.positionSec = v;
            }
        }
    }

    Process {
        id: statePoll
        command: ["sh", "-c", "len=$(playerctl metadata mpris:length 2>/dev/null); shf=$(playerctl shuffle 2>/dev/null); lp=$(playerctl loop 2>/dev/null); pv=$(playerctl volume 2>/dev/null); sv=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}'); echo \"$len|$shf|$lp|$pv|$sv\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split("|");
                if (p.length < 5)
                    return;
                const len = parseFloat(p[0]);
                root.lengthSec = !isNaN(len) ? len / 1000000 : 0;
                root.shuffleOn = p[1].trim() === "On";
                const lp = p[2].trim();
                root.loopMode = (lp === "Track" || lp === "Playlist") ? lp : "None";
                const pv = parseFloat(p[3]);
                if (!isNaN(pv)) {
                    root.volumeIsPlayer = true;
                    root.volume = Math.max(0, Math.min(1, pv));
                } else {
                    root.volumeIsPlayer = false;
                    const sv = parseFloat(p[4]);
                    root.volume = !isNaN(sv) ? Math.max(0, Math.min(1, sv)) : 0;
                }
            }
        }
    }

    Timer {
        id: posPoll
        running: root.shown
        interval: 1500
        repeat: true
        triggeredOnStart: true
        onTriggered: posProc.running = true
    }

    Timer {
        id: interp
        running: root.shown && root.playing && !root.seeking
        interval: 500
        repeat: true
        onTriggered: {
            if (root.lengthSec > 0)
                root.positionSec = Math.min(root.lengthSec, root.positionSec + 0.5);
            else
                root.positionSec += 0.5;
        }
    }

    Timer {
        id: refreshTimer
        interval: 120
        repeat: false
        onTriggered: statePoll.running = true
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
                source: root.artUrl
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
                source: root.artUrl
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
            text: root.track || "—"
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
            text: root.artist
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.7)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 11
            }
            elide: Text.ElideRight
            visible: root.artist !== ""
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.album
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.42)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 9
                italic: true
            }
            elide: Text.ElideRight
            visible: root.album !== ""
        }
    }

    Item {
        width: parent.width
        height: 22
        visible: root.playing && root.cavaValues.length > 0

        Row {
            anchors.centerIn: parent
            height: 20
            spacing: 3
            Repeater {
                model: root.cavaValues
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
            text: root.fmt(root.positionSec)
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
            text: root.fmt(root.lengthSec)
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
                visible: root.canSeek
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
                enabled: root.canSeek
                cursorShape: root.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                function seekTo(mx) {
                    const frac = Math.max(0, Math.min(1, mx / seekTrack.width));
                    root.positionSec = frac * root.lengthSec;
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
                    root.exec("playerctl position " + root.positionSec.toFixed(2));
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
            active: root.shuffleOn
            onActivated: {
                root.exec("playerctl shuffle Toggle");
                refreshTimer.restart();
            }
        }
        CtrlBtn {
            icon: "󰒮"
            onActivated: root.exec("playerctl previous")
        }
        CtrlBtn {
            icon: root.playing ? "󰏤" : "󰐊"
            primary: true
            onActivated: root.exec("playerctl play-pause")
        }
        CtrlBtn {
            icon: "󰒭"
            onActivated: root.exec("playerctl next")
        }
        CtrlBtn {
            icon: root.loopMode === "Track" ? "󰑘" : "󰑖"
            active: root.loopMode !== "None"
            onActivated: root.cycleLoop()
        }
    }

    Item {
        width: parent.width
        height: 22

        Text {
            id: volIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.volume <= 0 ? "󰖁" : root.volume < 0.5 ? "󰖀" : "󰕾"
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
            text: root.volumeIsPlayer ? "APP" : "SYS"
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
                width: parent.width * root.volume
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
                    root.setVolume(mx / volTrack.width);
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
