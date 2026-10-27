import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: greetingWindow

    required property var niriService
    required property var systemService
    required property var mediaService
    required property var cavaService
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
    readonly property bool revealed: greetingWindow.visible && !greetingWindow.dismissed
    property bool rested: false
    property bool dismissed: false
    property date now: new Date()

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
                return mediaService.title + " — " + mediaService.artist;
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
            restTimer.restart();
        } else {
            restTimer.stop();
            greetingWindow.rested = false;
            greetingWindow.dismissed = false;
        }
    }

    Component.onCompleted: {
        if (greetingWindow.workspaceEmpty)
            restTimer.restart();
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

    visible: greetingWindow.themeReady && greetingWindow.enabled && greetingWindow.rested
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
            color: Qt.rgba(greetingWindow.themeFg.r, greetingWindow.themeFg.g, greetingWindow.themeFg.b, 0.55)
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
            color: Qt.rgba(greetingWindow.themeFg.r, greetingWindow.themeFg.g, greetingWindow.themeFg.b, 0.16)

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * Math.max(0, Math.min(100, rowRoot.amount)) / 100
                height: parent.height
                radius: parent.radius
                color: Qt.rgba(greetingWindow.themeAccent.r, greetingWindow.themeAccent.g, greetingWindow.themeAccent.b, 0.85)
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
            color: greetingWindow.themeFg
            font {
                family: greetingWindow.barFont
                pixelSize: 13
                weight: Font.Medium
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: greetingWindow.rested && !greetingWindow.dismissed ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 1200
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: contentContainer
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -140
            width: contentRow.width + 32
            height: contentRow.height + 24

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: !greetingWindow.dismissed ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: greetingWindow.dismissed = !greetingWindow.dismissed
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: 150

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Row {
                        spacing: 18
                        transform: Translate {
                            x: -9
                        }

                        Text {
                            id: clockTime
                            text: greetingWindow.clockParts(greetingWindow.now).time
                            color: greetingWindow.themeFg
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
                            color: greetingWindow.themeSecond
                            opacity: 0.65
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
                        transform: Translate {
                            y: -20
                        }
                        text: greetingWindow.clockParts(greetingWindow.now).date
                        color: greetingWindow.themeSecond
                        opacity: 0.65
                        font {
                            family: greetingWindow.barFont
                            pixelSize: 16
                            weight: Font.Medium
                            letterSpacing: 2.5
                        }
                    }

                    Item {
                        width: 1
                        height: 16
                    }

                    Row {
                        spacing: 10

                        Text {
                            id: greetingHello
                            text: greetingWindow.clockParts(greetingWindow.now).hello
                            color: greetingWindow.themeFg
                            font {
                                family: greetingWindow.barFont
                                pixelSize: 28
                                weight: Font.Normal
                                letterSpacing: 1.5
                            }
                        }

                        Text {
                            text: "Rupan"
                            color: greetingWindow.themeAccent
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
                    anchors.verticalCenter: parent.verticalCenter
                    width: 400
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
                        color: Qt.rgba(greetingWindow.themeFg.r, greetingWindow.themeFg.g, greetingWindow.themeFg.b, 0.18)
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
                                    color: greetingWindow.themeAccent
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
                        color: Qt.rgba(greetingWindow.themeFg.r, greetingWindow.themeFg.g, greetingWindow.themeFg.b, 0.6)
                        elide: Text.ElideRight
                        font {
                            family: greetingWindow.barFont
                            pixelSize: 13
                            italic: true
                        }
                    }
                }
            }
        }
    }
}
