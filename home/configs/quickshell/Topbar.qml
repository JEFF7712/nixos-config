import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "services" as Services

PanelWindow {
    id: topbarWindow

    required property Services.AudioService audioService
    required property Services.MediaService mediaService
    required property Services.CavaService cavaService
    required property Services.PowerService powerService
    required property Services.SystemService systemService
    required property Services.NiriService niriService
    required property Services.NetworkService networkService
    required property Services.BluetoothService bluetoothService

    property color themeFg
    property color themeBg
    property color themeRawBg
    property color themeAccent
    property color themeSecond
    property color themeWarm
    property color themeFresh

    property int barRadius: 15
    property int barHeight: 44
    property int barMargin: 10
    property int barMarginTop: barMargin
    property int exclusiveZoneOffset: 0
    property bool showWorkspaces: true
    property bool showClock: true
    property bool showClockDate: true
    property bool showWorkspaceNumbers: true
    property bool showActiveWindow: false
    property bool showMedia: true
    property bool showVolume: true
    property bool showNetwork: true
    property bool showBluetooth: true
    property bool showBattery: true
    property bool showNotifications: true
    property bool showSystem: true
    property string barFont: "JetBrainsMono Nerd Font"
    property bool flatMode: false
    property bool showBarDividers: true
    property string moduleAnimationStyle: "fade"
    property color dividerColor: "#1affffff"
    property color barBorderColor: "#3dffffff"
    property color barInnerHighlight: "#0fffffff"
    property color pillBg: "#0affffff"
    property color pillBorder: "#14ffffff"

    property int notificationCount: 0
    readonly property bool cavaRequested: mediaPill.visible
    readonly property string activeTitle: topbarWindow.niriService.focusedTitle || topbarWindow.niriService.focusedAppId || "no active window"
    readonly property int activeWorkspaceIndex: {
        for (let i = 0; i < topbarWindow.niriService.workspaces.count; i++) {
            if (topbarWindow.niriService.workspaces.get(i).id === topbarWindow.niriService.activeWorkspaceId)
                return i;
        }
        return -1;
    }

    signal wifiClicked
    signal volumeClicked
    signal bluetoothClicked
    signal batteryClicked
    signal clockClicked
    signal notificationsClicked
    signal systemClicked
    signal mediaClicked

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function networkIcon() {
        return topbarWindow.networkService.connected ? "󰖩" : "󰖪";
    }

    function volumeIcon() {
        const percent = topbarWindow.audioService.volumePercent;
        if (topbarWindow.audioService.muted || percent <= 0)
            return "󰖁";
        if (percent < 34)
            return "󰕿";
        if (percent < 67)
            return "󰖀";
        return "󰕾";
    }

    function batteryIcon() {
        const percent = topbarWindow.powerService.chargePercent;
        if (!topbarWindow.powerService.available)
            return "󰁹";
        if (topbarWindow.powerService.state === "charging")
            return "󰂄";
        if (percent > 90)
            return "󰁹";
        if (percent > 70)
            return "󰂀";
        if (percent > 40)
            return "󰁾";
        if (percent > 10)
            return "󰁼";
        return "󰂎";
    }

    WlrLayershell.namespace: "quickshell-topbar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: topbarWindow.barMarginTop
        left: topbarWindow.barMargin
        right: topbarWindow.barMargin
    }
    implicitHeight: topbarWindow.barHeight
    exclusiveZone: topbarWindow.barHeight + (topbarWindow.barMarginTop > 0 ? topbarWindow.barMarginTop : 0) + topbarWindow.exclusiveZoneOffset
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: topbarWindow.barRadius
        color: topbarWindow.themeBg
        border.width: 1
        border.color: topbarWindow.barBorderColor

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: topbarWindow.barInnerHighlight
        }

        Item {
            id: workspacesArea
            visible: topbarWindow.showWorkspaces
            anchors.left: clockArea.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: topbarWindow.flatMode ? 0 : 14
            width: visible ? wsRow.implicitWidth : 0
            height: visible ? (topbarWindow.flatMode ? parent.height : wsRow.implicitHeight) : 0

            Row {
                id: wsRow
                spacing: topbarWindow.flatMode ? 0 : (topbarWindow.showWorkspaceNumbers ? 8 : 6)
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: topbarWindow.niriService.workspaces
                    delegate: WorkspacePill {
                        wsId: model.id
                        occupied: model.occupied
                        active: model.active
                        urgent: model.urgent
                    }
                }
            }

            Rectangle {
                id: wsIndicator
                visible: topbarWindow.showWorkspaceNumbers && !topbarWindow.flatMode
                width: 18
                height: 2
                radius: 1
                color: topbarWindow.themeAccent
                anchors.bottom: parent.bottom
                opacity: 0.9
                x: Math.max(0, topbarWindow.activeWorkspaceIndex) * 36 + 5
                Behavior on x {
                    SpringAnimation {
                        spring: 3.5
                        damping: 0.32
                        mass: 0.6
                    }
                }
            }
        }

        Row {
            id: rightGroup
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: topbarWindow.flatMode ? 0 : 12
            spacing: topbarWindow.flatMode ? 0 : 6

            StatPill {
                visible: topbarWindow.showVolume
                icon: topbarWindow.volumeIcon()
                value: (!topbarWindow.audioService.available || topbarWindow.audioService.muted || topbarWindow.audioService.volumePercent === 100 || topbarWindow.audioService.volumePercent === 0) ? "" : topbarWindow.audioService.volumePercent + "%"
                tint: topbarWindow.audioService.muted ? Qt.rgba(topbarWindow.themeFg.r, topbarWindow.themeFg.g, topbarWindow.themeFg.b, 0.4) : topbarWindow.themeAccent
                onActivated: topbarWindow.volumeClicked()
                onMiddleClicked: topbarWindow.audioService.toggleMute()
                onRightClicked: topbarWindow.audioService.openMixer()
                onScrolled: delta => topbarWindow.audioService.adjustVolume(delta)
            }
            StatPill {
                visible: topbarWindow.showNetwork
                icon: topbarWindow.networkIcon()
                value: ""
                tint: topbarWindow.themeSecond
                onActivated: topbarWindow.wifiClicked()
                onRightClicked: topbarWindow.networkService.openSettings()
            }
            StatPill {
                visible: topbarWindow.showBluetooth
                icon: "󰂯"
                value: ""
                tint: topbarWindow.themeSecond
                onActivated: topbarWindow.bluetoothClicked()
                onRightClicked: topbarWindow.bluetoothService.openManager()
            }
            StatPill {
                visible: topbarWindow.showBattery
                icon: topbarWindow.batteryIcon()
                value: !topbarWindow.powerService.available || topbarWindow.powerService.chargePercent === 100 ? "" : topbarWindow.powerService.chargePercent + "%"
                tint: topbarWindow.themeAccent
                onActivated: topbarWindow.batteryClicked()
                onRightClicked: topbarWindow.powerService.cycleProfile(1)
                onScrolled: delta => topbarWindow.powerService.cycleProfile(delta > 0 ? 1 : -1)
            }
            StatPill {
                visible: topbarWindow.showNotifications && topbarWindow.notificationCount > 0
                icon: "󰂚"
                value: topbarWindow.notificationCount > 9 ? "9+" : (topbarWindow.notificationCount > 0 ? topbarWindow.notificationCount.toString() : "")
                tint: topbarWindow.notificationCount > 0 ? topbarWindow.themeAccent : topbarWindow.themeSecond
                onActivated: topbarWindow.notificationsClicked()
            }
            StatPill {
                visible: topbarWindow.showSystem
                icon: ""
                value: ""
                tint: topbarWindow.themeAccent
                tintIcon: true
                onActivated: topbarWindow.systemClicked()
                onRightClicked: topbarWindow.systemService.lock()
            }
        }

        Item {
            id: clockArea
            visible: topbarWindow.showClock
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: topbarWindow.flatMode ? 0 : 14
            width: visible ? clockColumn.implicitWidth + 16 : 0
            height: visible ? (topbarWindow.flatMode ? topbarWindow.barHeight : clockColumn.implicitHeight + 8) : 0

            Rectangle {
                anchors.fill: parent
                radius: topbarWindow.flatMode ? 0 : 10
                color: clockMouse.pressed ? Qt.rgba(1, 1, 1, 0.12) : clockMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : topbarWindow.pillBg
                border.width: topbarWindow.flatMode ? 0 : 1
                border.color: clockMouse.containsMouse ? Qt.rgba(topbarWindow.themeAccent.r, topbarWindow.themeAccent.g, topbarWindow.themeAccent.b, 0.55) : topbarWindow.pillBorder

                Behavior on color {
                    ColorAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
            }

            ColumnLayout {
                id: clockColumn
                anchors.centerIn: parent
                spacing: -3

                Text {
                    id: clockTime
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatTime(new Date(), "h:mm AP")
                    color: topbarWindow.themeAccent
                    font {
                        family: topbarWindow.barFont
                        pixelSize: 12
                        weight: Font.Light
                        letterSpacing: 1.2
                    }
                    Timer {
                        interval: 10000
                        running: true
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: {
                            clockTime.text = Qt.formatTime(new Date(), "h:mm AP");
                            clockDate.text = Qt.formatDate(new Date(), "ddd d MMM").toUpperCase();
                        }
                    }
                }

                Text {
                    id: clockDate
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDate(new Date(), "ddd d MMM").toUpperCase()
                    color: topbarWindow.themeSecond
                    opacity: 0.6
                    font {
                        family: topbarWindow.barFont
                        pixelSize: 8
                        letterSpacing: 0.8
                        weight: Font.Medium
                    }
                    visible: topbarWindow.showClockDate
                }
            }

            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: topbarWindow.clockClicked()
            }
        }

        Item {
            id: mediaPill
            visible: topbarWindow.showMedia && topbarWindow.mediaService.available && topbarWindow.mediaService.status !== "Stopped"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            readonly property bool flat: topbarWindow.flatMode
            readonly property bool playing: topbarWindow.mediaService.playing
            readonly property color tint: playing ? topbarWindow.themeAccent : Qt.rgba(topbarWindow.themeFg.r, topbarWindow.themeFg.g, topbarWindow.themeFg.b, 0.55)

            width: mediaContent.implicitWidth + (flat ? 16 : 22)
            height: flat ? topbarWindow.barHeight : 26
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: mediaPill.flat ? 0 : 10
                color: mediaMouse.pressed ? Qt.rgba(1, 1, 1, 0.12) : mediaMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : topbarWindow.pillBg
                Behavior on color {
                    ColorAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                border.width: mediaPill.flat ? 0 : 1
                border.color: mediaMouse.containsMouse ? Qt.rgba(mediaPill.tint.r, mediaPill.tint.g, mediaPill.tint.b, 0.55) : topbarWindow.pillBorder
                Behavior on border.color {
                    ColorAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                scale: mediaPill.flat ? 1.0 : (mediaMouse.pressed ? 0.94 : 1.0)
                Behavior on scale {
                    SpringAnimation {
                        spring: 3
                        damping: 0.55
                        mass: 0.8
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: mediaPill.tint
                    opacity: mediaMouse.containsMouse ? 0.18 : 0.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                RowLayout {
                    id: mediaContent
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: mediaPill.playing ? "󰏤" : "󰐊"
                        color: mediaMouse.containsMouse ? mediaPill.tint : Qt.rgba(topbarWindow.themeFg.r, topbarWindow.themeFg.g, topbarWindow.themeFg.b, 0.75)
                        font {
                            family: topbarWindow.barFont
                            pixelSize: 12
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        text: topbarWindow.mediaService.title.length > 26 ? topbarWindow.mediaService.title.substring(0, 25) + "…" : topbarWindow.mediaService.title
                        color: topbarWindow.themeFg
                        opacity: 0.85
                        font {
                            family: topbarWindow.barFont
                            pixelSize: 10
                            weight: Font.Medium
                        }
                    }

                    Row {
                        id: cavaRow
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        height: 14
                        spacing: 2
                        visible: mediaPill.playing && topbarWindow.cavaService.values.length > 0

                        Repeater {
                            model: topbarWindow.cavaService.values
                            delegate: Rectangle {
                                width: 2
                                radius: 1
                                anchors.bottom: parent.bottom
                                height: Math.max(2, Math.min(14, (modelData / 100) * 14))
                                color: mediaPill.tint
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
            }

            MouseArea {
                id: mediaMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton)
                        topbarWindow.mediaService.togglePlaying();
                    else
                        topbarWindow.mediaClicked();
                }
                onWheel: event => {
                    if (event.angleDelta.y > 0)
                        topbarWindow.mediaService.next();
                    else if (event.angleDelta.y < 0)
                        topbarWindow.mediaService.previous();
                    event.accepted = true;
                }
            }
        }

        RowLayout {
            visible: topbarWindow.showActiveWindow
            anchors.left: workspacesArea.right
            anchors.right: rightGroup.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 9

            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: topbarWindow.themeFresh
                opacity: topbarWindow.activeTitle !== "no active window" ? 1.0 : 0.2
                SequentialAnimation on opacity {
                    running: topbarWindow.activeTitle !== "no active window"
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.45
                        duration: 1400
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1.0
                        duration: 1400
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: topbarWindow.activeTitle
                color: topbarWindow.activeTitle === "no active window" ? Qt.rgba(topbarWindow.themeFg.r, topbarWindow.themeFg.g, topbarWindow.themeFg.b, 0.4) : topbarWindow.themeFg
                elide: Text.ElideRight
                font {
                    family: topbarWindow.barFont
                    pixelSize: 12
                    weight: Font.Medium
                    letterSpacing: 0.3
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    component WorkspacePill: Item {
        id: wsRoot
        property int wsId: 1
        property bool occupied: false
        property bool active: false
        property bool urgent: false
        readonly property bool isActive: wsRoot.active
        readonly property bool isOccupied: wsRoot.occupied
        readonly property bool noNumbers: !topbarWindow.showWorkspaceNumbers
        readonly property bool flat: topbarWindow.flatMode

        width: flat ? (topbarWindow.showWorkspaceNumbers ? 28 : 18) : (noNumbers ? (isActive ? 30 : 14) : 28)
        height: flat ? topbarWindow.barHeight : (noNumbers ? 14 : 24)

        Behavior on width {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: wsBase
            anchors.fill: parent
            radius: wsRoot.flat ? 0 : (wsRoot.noNumbers ? 4 : 9)

            color: (wsRoot.flat && topbarWindow.showWorkspaceNumbers) ? "transparent" : wsRoot.noNumbers ? Qt.rgba(topbarWindow.themeAccent.r, topbarWindow.themeAccent.g, topbarWindow.themeAccent.b, wsRoot.isActive ? 1.0 : wsMouse.containsMouse ? 0.7 : wsRoot.isOccupied ? 0.55 : 0.25) : (wsMouse.pressed ? Qt.rgba(1, 1, 1, 0.12) : wsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, wsRoot.isOccupied ? 0.05 : 0.025))
            Behavior on color {
                ColorAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            border.width: (wsRoot.noNumbers || wsRoot.flat) ? 0 : 1
            border.color: wsRoot.isActive ? "transparent" : wsMouse.containsMouse ? Qt.rgba(topbarWindow.themeAccent.r, topbarWindow.themeAccent.g, topbarWindow.themeAccent.b, 0.55) : Qt.rgba(1, 1, 1, wsRoot.isOccupied ? 0.16 : 0.06)
            Behavior on border.color {
                ColorAnimation {
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }

            scale: wsRoot.flat ? 1.0 : (wsMouse.pressed ? 0.94 : (wsMouse.containsMouse ? 1.06 : 1.0))
            Behavior on scale {
                SpringAnimation {
                    spring: 3
                    damping: 0.55
                    mass: 0.8
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: topbarWindow.themeAccent
                opacity: wsRoot.isActive && (!wsRoot.noNumbers || wsRoot.flat) ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutQuart
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: wsRoot.wsId
                visible: topbarWindow.showWorkspaceNumbers
                color: wsRoot.isActive ? topbarWindow.themeRawBg : wsRoot.isOccupied ? topbarWindow.themeFg : Qt.rgba(topbarWindow.themeFg.r, topbarWindow.themeFg.g, topbarWindow.themeFg.b, 0.32)
                font {
                    family: topbarWindow.barFont
                    pixelSize: wsRoot.isActive ? 12 : 11
                    weight: wsRoot.isActive ? Font.Bold : Font.Medium
                }
                scale: wsMouse.pressed ? 0.9 : (wsMouse.containsMouse ? 1.08 : 1.0)
                Behavior on scale {
                    SpringAnimation {
                        spring: 4
                        damping: 0.5
                        mass: 0.7
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Rectangle {
            visible: wsRoot.flat && topbarWindow.showBarDividers
            width: 1
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: topbarWindow.dividerColor
        }

        MouseArea {
            id: wsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: topbarWindow.niriService.focusWorkspace(wsRoot.wsId)
            onWheel: event => {
                topbarWindow.niriService.focusAdjacent(event.angleDelta.y > 0 ? -1 : 1);
                event.accepted = true;
            }
        }
    }

    component StatPill: Item {
        id: statRoot
        property string icon
        property string value
        property color tint
        property bool tintIcon: false
        signal activated
        signal middleClicked
        signal rightClicked
        signal scrolled(int delta)

        readonly property bool flat: topbarWindow.flatMode
        readonly property bool hasValue: statRoot.value !== ""
        readonly property bool slideValue: topbarWindow.moduleAnimationStyle === "slide"

        width: statContent.implicitWidth + (flat ? 16 : 22)
        height: flat ? topbarWindow.barHeight : 26
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: statRoot.flat ? 0 : 10
            color: statMouse.pressed ? Qt.rgba(1, 1, 1, 0.12) : statMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : topbarWindow.pillBg
            Behavior on color {
                ColorAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            border.width: statRoot.flat ? 0 : 1
            border.color: statMouse.containsMouse ? Qt.rgba(statRoot.tint.r, statRoot.tint.g, statRoot.tint.b, 0.55) : topbarWindow.pillBorder
            Behavior on border.color {
                ColorAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }

            scale: statRoot.flat ? 1.0 : (statMouse.pressed ? 0.94 : 1.0)
            Behavior on scale {
                SpringAnimation {
                    spring: 3
                    damping: 0.55
                    mass: 0.8
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: statRoot.tint
                opacity: statMouse.containsMouse ? 0.18 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutCubic
                    }
                }
            }

            RowLayout {
                id: statContent
                anchors.centerIn: parent
                spacing: 6

                Item {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16

                    Text {
                        id: statIcon
                        anchors.centerIn: parent
                        width: parent.width
                        text: statRoot.icon
                        horizontalAlignment: Text.AlignHCenter
                        color: (statRoot.tintIcon || statMouse.containsMouse) ? statRoot.tint : Qt.rgba(topbarWindow.themeFg.r, topbarWindow.themeFg.g, topbarWindow.themeFg.b, 0.75)
                        font {
                            family: topbarWindow.barFont
                            pixelSize: 12
                        }
                        scale: statMouse.pressed ? 0.9 : (statMouse.containsMouse ? 1.08 : 1.0)
                        Behavior on scale {
                            SpringAnimation {
                                spring: 4
                                damping: 0.5
                                mass: 0.7
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                Item {
                    implicitWidth: statRoot.hasValue ? valueText.implicitWidth : 0
                    implicitHeight: valueText.implicitHeight
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    visible: statRoot.slideValue || statRoot.hasValue
                    clip: statRoot.slideValue

                    Behavior on Layout.preferredWidth {
                        enabled: statRoot.slideValue
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        id: valueText
                        text: statRoot.value
                        x: statRoot.slideValue && !statRoot.hasValue ? -implicitWidth : 0
                        color: topbarWindow.themeFg
                        opacity: statRoot.slideValue ? 0.85 : (statRoot.hasValue ? 0.85 : 0.0)
                        font {
                            family: topbarWindow.barFont
                            pixelSize: 10
                            weight: Font.Medium
                        }

                        Behavior on x {
                            enabled: statRoot.slideValue
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on opacity {
                            enabled: !statRoot.slideValue
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: statMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    statRoot.middleClicked();
                else if (mouse.button === Qt.RightButton)
                    statRoot.rightClicked();
                else
                    statRoot.activated();
            }
            onWheel: event => {
                statRoot.scrolled(event.angleDelta.y);
                event.accepted = true;
            }
        }

        Rectangle {
            visible: statRoot.flat && topbarWindow.showBarDividers
            width: 1
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: topbarWindow.dividerColor
        }
    }
}
