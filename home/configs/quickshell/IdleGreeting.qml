import QtQuick
import Quickshell
import Quickshell.Wayland
import "services" as Services

PanelWindow {
    id: greetingWindow

    required property var niriService
    required property var systemService
    required property var mediaService
    required property var cavaService
    required property var bluetoothService
    property color themeFg: "#ffffff"
    property color themeSecond: "#e8e8e8"
    property color themeAccent: "#ffffff"
    property string barFont: "JetBrainsMono Nerd Font"
    property bool themeReady: false
    property bool enabled: false

    readonly property bool workspaceEmpty: {
        for (let i = 0; i < niriService.workspaces.count; i++) {
            const ws = niriService.workspaces.get(i);
            if (ws.output === greetingWindow.screen.name && ws.active)
                return !ws.occupied;
        }
        return false;
    }
    readonly property int idleDelayMs: 3000
    readonly property int layoutMotionMs: 650
    readonly property bool revealed: greetingWindow.visible && !greetingWindow.dismissed
    property bool rested: false
    property bool dismissed: false
    property bool poseSettled: false
    readonly property bool motionActive: greetingWindow.visible && greetingWindow.poseSettled && fadeRoot.opacity > 0.01
    property date now: new Date()
    readonly property bool compact: !placementService.result || placementService.result.name === "compact"
    property real compactProgress: greetingWindow.compact ? 1 : 0
    readonly property real compactWidth: 400
    readonly property real wideClockHeight: 260
    readonly property real compactClockHeight: 184
    readonly property int connectedDeviceCount: bluetoothService.available && bluetoothService.enabled ? bluetoothService.connectedCount : 0
    readonly property int deviceRows: Math.ceil(greetingWindow.connectedDeviceCount / 3)
    readonly property real statsHeight: 236 + (greetingWindow.deviceRows > 0 ? 36 + greetingWindow.deviceRows * 120 + (greetingWindow.deviceRows - 1) * 16 : 0)
    readonly property real wideInnerHeight: Math.max(greetingWindow.wideClockHeight, greetingWindow.statsHeight)
    readonly property real compactInnerHeight: greetingWindow.compactClockHeight + 24 + greetingWindow.statsHeight
    readonly property var layoutCandidates: [
        {
            name: "wide",
            width: 1048,
            height: greetingWindow.wideInnerHeight + 48
        },
        {
            name: "compact",
            width: greetingWindow.compactWidth + 48,
            height: greetingWindow.compactInnerHeight + 48
        }
    ]
    property color contentAccent: placementService.result ? placementService.result.accent : greetingWindow.themeAccent
    property color contentFg: placementService.result && placementService.result.foreground ? placementService.result.foreground : greetingWindow.themeFg

    Behavior on compactProgress {
        enabled: greetingWindow.motionActive
        NumberAnimation {
            duration: greetingWindow.layoutMotionMs
            easing.type: Easing.InOutCubic
        }
    }

    Behavior on contentAccent {
        enabled: greetingWindow.motionActive
        ColorAnimation {
            duration: greetingWindow.layoutMotionMs
            easing.type: Easing.InOutCubic
        }
    }

    Behavior on contentFg {
        enabled: greetingWindow.motionActive
        ColorAnimation {
            duration: greetingWindow.layoutMotionMs
            easing.type: Easing.InOutCubic
        }
    }

    Services.WallpaperLayout {
        id: placementService
        screenName: greetingWindow.screen ? greetingWindow.screen.name : ""
        viewportWidth: greetingWindow.screen ? greetingWindow.screen.width : 0
        viewportHeight: greetingWindow.screen ? greetingWindow.screen.height : 0
        candidates: greetingWindow.layoutCandidates
        foreground: greetingWindow.themeFg
        accent: greetingWindow.themeAccent
        enabled: greetingWindow.enabled && greetingWindow.themeReady
    }

    onRestedChanged: if (greetingWindow.rested)
        placementService.refresh()

    readonly property bool sysAvailable: systemService.available
    readonly property string cpuValue: greetingWindow.sysAvailable ? systemService.cpuPercent + "%" : "-"
    readonly property int cpuAmount: greetingWindow.sysAvailable ? systemService.cpuPercent : 0
    readonly property string ramValue: greetingWindow.sysAvailable ? systemService.ramUsedGiB.toFixed(1) + "G" : "-"
    readonly property int ramAmount: greetingWindow.sysAvailable ? systemService.ramPercent : 0
    readonly property string diskValue: greetingWindow.sysAvailable ? systemService.diskPercent + "%" : "-"
    readonly property int diskAmount: greetingWindow.sysAvailable ? systemService.diskPercent : 0
    readonly property string trackLine: {
        if (mediaService.available && mediaService.title !== "") {
            if (mediaService.artist !== "")
                return mediaService.title + " / " + mediaService.artist;
            return mediaService.title;
        }
        return "nothing playing";
    }

    function greetingFor(date) {
        const hour = date.getHours();
        if (hour < 5)
            return "Good night";
        if (hour < 12)
            return "Good morning";
        if (hour < 18)
            return "Good afternoon";
        return "Good evening";
    }

    function clockParts(date) {
        const h = date.getHours();
        return {
            time: ((h % 12) || 12) + ":" + ("0" + date.getMinutes()).slice(-2),
            ap: h < 12 ? "AM" : "PM",
            date: Qt.formatDate(date, "dddd, d MMM").toUpperCase(),
            hello: greetingWindow.greetingFor(date) + ","
        };
    }

    onWorkspaceEmptyChanged: {
        if (greetingWindow.workspaceEmpty) {
            greetingWindow.dismissed = false;
            placementService.refresh();
            restTimer.restart();
        } else {
            restTimer.stop();
            greetingWindow.rested = false;
            greetingWindow.dismissed = false;
        }
    }

    onVisibleChanged: {
        if (greetingWindow.visible) {
            poseEnableTimer.restart();
        } else {
            poseEnableTimer.stop();
            greetingWindow.poseSettled = false;
        }
    }

    Component.onCompleted: {
        if (greetingWindow.workspaceEmpty)
            restTimer.restart();
    }

    Timer {
        id: poseEnableTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (greetingWindow.visible)
                greetingWindow.poseSettled = true;
        }
    }

    Timer {
        id: restTimer
        interval: greetingWindow.idleDelayMs
        repeat: false
        onTriggered: greetingWindow.rested = true
    }

    Timer {
        id: clockTimer
        interval: 10000
        running: greetingWindow.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: greetingWindow.now = new Date()
    }

    WlrLayershell.namespace: "quickshell-idle-greeting"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: greetingWindow.themeReady && greetingWindow.enabled && greetingWindow.rested && placementService.result !== null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "transparent"

    mask: Region {
        item: contentContainer
    }

    component StatRow: Item {
        id: rowRoot
        property string label: ""
        property string value: "-"
        property int amount: 0

        width: parent.width
        height: 32

        Text {
            id: rowLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            text: rowRoot.label
            color: Qt.rgba(greetingWindow.contentFg.r, greetingWindow.contentFg.g, greetingWindow.contentFg.b, 0.78)
            font {
                family: greetingWindow.barFont
                pixelSize: 13
                weight: Font.Medium
                letterSpacing: 1.5
            }
        }

        Rectangle {
            anchors.left: rowLabel.right
            anchors.right: rowValue.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 5
            radius: 2
            color: Qt.rgba(greetingWindow.contentFg.r, greetingWindow.contentFg.g, greetingWindow.contentFg.b, 0.16)

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * Math.max(0, Math.min(100, rowRoot.amount)) / 100
                height: parent.height
                radius: parent.radius
                color: greetingWindow.contentAccent
                Behavior on width {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Text {
            id: rowValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: rowRoot.value
            color: greetingWindow.contentFg
            font {
                family: greetingWindow.barFont
                pixelSize: 13
                weight: Font.Medium
            }
        }
    }

    Item {
        id: fadeRoot
        anchors.fill: parent
        opacity: greetingWindow.visible && !greetingWindow.dismissed ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 1200
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: contentContainer
            readonly property real u: greetingWindow.compactProgress
            x: placementService.result ? placementService.result.x : 24
            y: placementService.result ? placementService.result.y : 24
            width: 1048 + (greetingWindow.compactWidth + 48 - 1048) * u
            height: greetingWindow.wideInnerHeight + (greetingWindow.compactInnerHeight - greetingWindow.wideInnerHeight) * u + 48
            scale: placementService.result ? placementService.result.scale : 1
            transformOrigin: Item.TopLeft

            Behavior on x {
                enabled: greetingWindow.motionActive
                NumberAnimation {
                    duration: greetingWindow.layoutMotionMs
                    easing.type: Easing.InOutCubic
                }
            }

            Behavior on y {
                enabled: greetingWindow.motionActive
                NumberAnimation {
                    duration: greetingWindow.layoutMotionMs
                    easing.type: Easing.InOutCubic
                }
            }

            Behavior on scale {
                enabled: greetingWindow.motionActive
                NumberAnimation {
                    duration: greetingWindow.layoutMotionMs
                    easing.type: Easing.InOutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: !greetingWindow.dismissed ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: greetingWindow.dismissed = !greetingWindow.dismissed
            }

            Item {
                id: contentLayout
                anchors.fill: parent
                anchors.margins: 24

                Item {
                    id: clockGroup
                    readonly property real u: greetingWindow.compactProgress
                    readonly property real wideY: (greetingWindow.wideInnerHeight - greetingWindow.wideClockHeight) / 2

                    width: 520 + (greetingWindow.compactWidth - 520) * u
                    height: greetingWindow.wideClockHeight + (greetingWindow.compactClockHeight - greetingWindow.wideClockHeight) * u
                    y: (1 - u) * (1 - u) * wideY

                    Row {
                        id: timeRow
                        x: -9 * scale
                        spacing: 18
                        scale: 1 + (84 / 132 - 1) * clockGroup.u
                        transformOrigin: Item.TopLeft

                        Text {
                            id: clockTime
                            text: greetingWindow.clockParts(greetingWindow.now).time
                            color: greetingWindow.contentFg
                            renderType: Text.CurveRendering
                            font {
                                family: greetingWindow.barFont
                                pixelSize: 132
                                weight: Font.Light
                                letterSpacing: 2
                            }
                        }

                        Text {
                            id: ampmText
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 30
                            text: greetingWindow.clockParts(greetingWindow.now).ap
                            color: greetingWindow.contentFg
                            opacity: 0.78
                            renderType: Text.CurveRendering
                            scale: 1 + ((15 / 19) / (84 / 132) - 1) * clockGroup.u
                            transformOrigin: Item.BottomLeft

                            font {
                                family: greetingWindow.barFont
                                pixelSize: 19
                                weight: Font.Medium
                                letterSpacing: 3
                            }
                        }
                    }

                    Text {
                        id: clockDate
                        y: timeRow.height * timeRow.scale - (18 - 6 * clockGroup.u)
                        scale: 1 + (14 / 16 - 1) * clockGroup.u
                        transformOrigin: Item.TopLeft
                        text: greetingWindow.clockParts(greetingWindow.now).date
                        color: greetingWindow.contentFg
                        opacity: 0.78
                        renderType: Text.CurveRendering

                        font {
                            family: greetingWindow.barFont
                            pixelSize: 16
                            weight: Font.Medium
                            letterSpacing: 2.5
                        }
                    }

                    Row {
                        id: greetingRow
                        y: timeRow.height * timeRow.scale + clockDate.height * clockDate.scale + (22 - 8 * clockGroup.u)
                        spacing: 10
                        scale: 1 + (22 / 28 - 1) * clockGroup.u
                        transformOrigin: Item.TopLeft

                        Text {
                            id: greetingHello
                            text: greetingWindow.clockParts(greetingWindow.now).hello
                            color: greetingWindow.contentFg
                            renderType: Text.CurveRendering
                            font {
                                family: greetingWindow.barFont
                                pixelSize: 28
                                weight: Font.Normal
                                letterSpacing: 1.5
                            }
                        }

                        Text {
                            text: "Rupan"
                            color: greetingWindow.contentAccent
                            renderType: Text.CurveRendering
                            font {
                                family: greetingWindow.barFont
                                pixelSize: 28
                                weight: Font.Normal
                                letterSpacing: 1.5
                            }
                        }
                    }
                }

                Column {
                    id: statsGroup
                    readonly property real u: greetingWindow.compactProgress
                    readonly property real wideY: (greetingWindow.wideInnerHeight - greetingWindow.statsHeight) / 2
                    readonly property real compactY: greetingWindow.compactClockHeight + 24

                    x: (1 - u) * (600 + 580 * u)
                    y: (1 - u) * wideY + u * compactY + 208 * u * (1 - u)
                    width: greetingWindow.compactWidth
                    height: greetingWindow.statsHeight
                    spacing: 8

                    StatRow {
                        label: "CPU"
                        value: greetingWindow.cpuValue
                        amount: greetingWindow.cpuAmount
                    }

                    StatRow {
                        label: "RAM"
                        value: greetingWindow.ramValue
                        amount: greetingWindow.ramAmount
                    }

                    StatRow {
                        label: "DSK"
                        value: greetingWindow.diskValue
                        amount: greetingWindow.diskAmount
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(greetingWindow.contentFg.r, greetingWindow.contentFg.g, greetingWindow.contentFg.b, 0.18)
                    }

                    Item {
                        width: parent.width
                        height: 76

                        Row {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 76
                            spacing: 6
                            opacity: greetingWindow.cavaService.values.length > 0 ? 1 : 0.3
                            Repeater {
                                model: Math.max(12, greetingWindow.cavaService.values.length)
                                delegate: Rectangle {
                                    readonly property int barValue: index < greetingWindow.cavaService.values.length ? greetingWindow.cavaService.values[index] : 0
                                    width: (400 - 11 * 6) / 12
                                    radius: 3
                                    anchors.bottom: parent.bottom
                                    height: Math.max(4, Math.min(76, (barValue / 100) * 76))
                                    color: greetingWindow.contentAccent
                                    Behavior on height {
                                        NumberAnimation {
                                            duration: 90
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: greetingWindow.trackLine
                        color: Qt.rgba(greetingWindow.contentFg.r, greetingWindow.contentFg.g, greetingWindow.contentFg.b, 0.78)
                        elide: Text.ElideRight
                        font {
                            family: greetingWindow.barFont
                            pixelSize: 13
                            italic: true
                        }
                    }

                    BluetoothDevices {
                        width: parent.width
                        topPadding: 8
                        bluetoothService: greetingWindow.bluetoothService
                        themeFg: greetingWindow.contentFg
                        themeAccent: greetingWindow.contentAccent
                        labelOpacity: 0.78
                        mutedOpacity: 0.72
                        barFont: greetingWindow.barFont
                    }
                }
            }
        }
    }
}
