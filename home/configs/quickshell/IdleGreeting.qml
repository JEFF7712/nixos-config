import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services" as Services

PanelWindow {
    id: greetingWindow

    required property var niriService
    required property var systemService
    required property var mediaService
    required property var cavaService
    required property var bluetoothService
    required property var powerService
    required property var agentFeed
    required property var homelabFeed
    required property var calendarFeed
    property color themeFg: "#ffffff"
    property color themeSecond: "#e8e8e8"
    property color themeAccent: "#ffffff"
    property string barFont: "JetBrainsMono Nerd Font"
    property bool themeReady: false
    property bool enabled: false
    property int themeRevision: 0

    // Wallpaper change choreography: hold the current pose and palette while the
    // new layout and theme settle, then move and recolour in one animation.
    property string wallpaperPath: ""
    property string lastTransitionStamp: ""
    readonly property real createdAtMs: Date.now()
    property bool transitioning: false
    property bool awaitingTheme: false
    readonly property bool transitionReady: !greetingWindow.awaitingTheme && placementService.ready
    // The pose on screen; follows placementService.result except while a wallpaper change is settling.
    property var pose: null

    function beginWallpaperTransition(info) {
        greetingWindow.transitioning = true;
        greetingWindow.awaitingTheme = info.themed === true;
        greetingWindow.wallpaperPath = info.wallpaper || "";
        transitionSafetyTimer.restart();
    }

    function finishWallpaperTransition() {
        transitionSafetyTimer.stop();
        greetingWindow.awaitingTheme = false;
        greetingWindow.transitioning = false;
        greetingWindow.pose = placementService.result;
    }

    onThemeRevisionChanged: greetingWindow.awaitingTheme = false
    onTransitionReadyChanged: if (greetingWindow.transitioning && greetingWindow.transitionReady)
        greetingWindow.finishWallpaperTransition()

    Timer {
        id: transitionSafetyTimer
        interval: 4000
        onTriggered: greetingWindow.finishWallpaperTransition()
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/desktop-profiles/wallpaper-transition"
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onLoaded: {
            let info;
            try {
                info = JSON.parse(this.text());
            } catch (e) {
                return;
            }
            if (info.stamp === greetingWindow.lastTransitionStamp)
                return;
            greetingWindow.lastTransitionStamp = info.stamp;
            // A stamp older than this window is startup state, not a change in progress.
            if (Number(info.stamp) / 1e6 < greetingWindow.createdAtMs)
                greetingWindow.wallpaperPath = info.wallpaper || "";
            else
                greetingWindow.beginWallpaperTransition(info);
        }
    }

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
    readonly property bool compact: !greetingWindow.pose || greetingWindow.pose.name === "compact"
    property real compactProgress: greetingWindow.compact ? 1 : 0
    readonly property real compactWidth: 400
    readonly property real wideClockHeight: 260
    readonly property real compactClockHeight: 184
    readonly property int connectedDeviceCount: bluetoothService.available && bluetoothService.enabled ? bluetoothService.connectedCount : 0
    readonly property int deviceRows: Math.ceil(greetingWindow.connectedDeviceCount / 3)
    readonly property bool batteryShown: !!powerService && powerService.available
    readonly property var agentRows: agentFeed && agentFeed.result && agentFeed.result.ok ? agentFeed.result.agents : []
    // Band layout trades the bluetooth tiles and two agent rows for a short horizontal strip.
    readonly property int maxAgentLines: greetingWindow.band ? 3 : 5
    readonly property var agentLines: greetingWindow.agentLinesFor(greetingWindow.maxAgentLines)
    readonly property int agentOverflow: greetingWindow.agentRows.length - greetingWindow.agentLines.length
    readonly property var nextEvent: calendarFeed && calendarFeed.result && calendarFeed.result.events && calendarFeed.result.events.length > 0 ? calendarFeed.result.events[0] : null
    readonly property var labData: homelabFeed ? homelabFeed.result : null
    readonly property int infoLineCount: greetingWindow.infoLinesFor(greetingWindow.maxAgentLines)
    readonly property real statsHeight: greetingWindow.statsHeightFor(5, true)
    readonly property real bandRestHeight: greetingWindow.statsHeightFor(3, false) - greetingWindow.sysBlock
    readonly property real bandColumnWidth: 400
    readonly property real bandGap: 48
    readonly property real bandWidth: greetingWindow.splitClockWidth + greetingWindow.bandGap * 2 + greetingWindow.bandColumnWidth * 2
    readonly property real bandHeight: Math.max(greetingWindow.wideClockHeight, greetingWindow.sysHeight, greetingWindow.bandRestHeight)

    function agentLinesFor(maxLines) {
        const rows = greetingWindow.agentRows;
        return rows.length <= maxLines ? rows : rows.slice(0, maxLines - 1);
    }

    function infoLinesFor(maxLines) {
        const shown = greetingWindow.agentLinesFor(maxLines).length;
        return (greetingWindow.nextEvent ? 1 : 0) + (greetingWindow.labData ? 1 : 0) + shown + (greetingWindow.agentRows.length > shown ? 1 : 0);
    }

    function statsHeightFor(maxLines, withDevices) {
        const lines = greetingWindow.infoLinesFor(maxLines);
        return 236 + (greetingWindow.batteryShown ? 40 : 0) + (lines > 0 ? 9 + lines * 34 : 0) + (withDevices && greetingWindow.deviceRows > 0 ? 36 + greetingWindow.deviceRows * 120 + (greetingWindow.deviceRows - 1) * 16 : 0);
    }
    readonly property int sysRowCount: 3 + (greetingWindow.batteryShown ? 1 : 0)
    // CPU/RAM/DSK/BAT rows plus their divider; in split mode they sit under the clock.
    readonly property real sysHeight: greetingWindow.sysRowCount * 40 + 1
    readonly property real sysBlock: greetingWindow.sysHeight + 8
    readonly property real splitClockHeight: greetingWindow.wideClockHeight + 24 + greetingWindow.sysHeight
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
        },
        {
            name: "split",
            width: greetingWindow.splitClockWidth + 48,
            height: greetingWindow.splitClockHeight + 48,
            width2: greetingWindow.compactWidth + 48,
            height2: greetingWindow.statsHeight - greetingWindow.sysBlock + 48
        },
        {
            name: "band",
            width: greetingWindow.bandWidth + 48,
            height: greetingWindow.bandHeight + 48
        }
    ]
    readonly property bool band: greetingWindow.pose !== null && greetingWindow.pose.name === "band"
    property real bandProgress: greetingWindow.band ? 1 : 0

    Behavior on bandProgress {
        enabled: greetingWindow.motionActive
        NumberAnimation {
            duration: greetingWindow.layoutMotionMs
            easing.type: Easing.InOutCubic
        }
    }
    readonly property real splitClockWidth: 520
    readonly property bool split: greetingWindow.pose !== null && greetingWindow.pose.name === "split"
    property real splitProgress: greetingWindow.split ? 1 : 0
    // Last split pose, kept so the panels can animate back together after the layout leaves split.
    property var splitPose: null
    readonly property var splitGeom: {
        const p = greetingWindow.splitPose;
        if (!p)
            return {
                left: 0,
                top: 0,
                clockX: 0,
                clockY: 0,
                statsX: 0,
                statsY: 0,
                width: 1048,
                height: greetingWindow.wideInnerHeight + 48
            };
        const s = p.scale;
        const left = Math.min(p.x, p.x2);
        const top = Math.min(p.y, p.y2);
        return {
            left: left,
            top: top,
            clockX: (p.x - left) / s,
            clockY: (p.y - top) / s,
            statsX: (p.x2 - left) / s,
            statsY: (p.y2 - top) / s,
            width: (Math.max(p.x + p.width * s, p.x2 + p.width2 * s) - left) / s,
            height: (Math.max(p.y + p.height * s, p.y2 + p.height2 * s) - top) / s
        };
    }

    Connections {
        target: placementService
        function onResultChanged() {
            if (!greetingWindow.transitioning)
                greetingWindow.pose = placementService.result;
        }
    }

    onPoseChanged: if (greetingWindow.pose && greetingWindow.pose.name === "split")
        greetingWindow.splitPose = greetingWindow.pose

    Behavior on splitProgress {
        enabled: greetingWindow.motionActive
        NumberAnimation {
            duration: greetingWindow.layoutMotionMs
            easing.type: Easing.InOutCubic
        }
    }
    // Busy wallpapers: a feathered scrim behind each panel, as strong as placement says
    // the text needs (0 on clean wallpapers), animated with the move.
    property real scrimOpacity: greetingWindow.pose && greetingWindow.pose.backdropOpacity ? Math.min(0.85, greetingWindow.pose.backdropOpacity) : 0
    property color scrimColor: greetingWindow.pose && greetingWindow.pose.backdropColor ? greetingWindow.pose.backdropColor : "#000000"

    Behavior on scrimOpacity {
        enabled: greetingWindow.motionActive
        NumberAnimation {
            duration: greetingWindow.layoutMotionMs
            easing.type: Easing.InOutCubic
        }
    }

    component Scrim: RectangularShadow {
        required property Item target
        x: target.x - 12
        y: target.y - 8
        width: target.width + 24
        height: target.height + 16
        radius: 48
        blur: 96
        color: greetingWindow.scrimColor
        opacity: greetingWindow.scrimOpacity
        visible: opacity > 0.01 && target.visible
    }

    property color contentAccent: greetingWindow.pose ? greetingWindow.pose.accent : greetingWindow.themeAccent
    property color contentFg: greetingWindow.pose && greetingWindow.pose.foreground ? greetingWindow.pose.foreground : greetingWindow.themeFg

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
        wallpaper: greetingWindow.wallpaperPath
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

    readonly property color okColor: greetingWindow.contentAccent
    readonly property color warnColor: "#f2c14e"
    readonly property color badColor: "#ff6b6b"

    function shortDuration(seconds) {
        if (seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        return h > 0 ? h + "h" + ("0" + m).slice(-2) + "m" : m + "m";
    }

    readonly property string batteryValue: {
        const pct = powerService.chargePercent + "%";
        const left = greetingWindow.shortDuration(powerService.secondsRemaining);
        switch (powerService.state) {
        case "charging":
            return left ? pct + " · full in " + left : pct + " · charging";
        case "discharging":
            return left ? pct + " · " + left : pct;
        case "pending-charge":
            return pct + " · held";
        case "full":
            return pct + " · full";
        default:
            return pct;
        }
    }

    function clockTime(date) {
        return ((date.getHours() % 12) || 12) + ":" + ("0" + date.getMinutes()).slice(-2) + (date.getHours() < 12 ? " AM" : " PM");
    }

    function dayDelta(from, to) {
        const a = new Date(from.getFullYear(), from.getMonth(), from.getDate());
        const b = new Date(to.getFullYear(), to.getMonth(), to.getDate());
        return Math.round((b - a) / 86400000);
    }

    function eventWhen(ev, now) {
        const start = new Date(ev.start);
        const end = new Date(ev.end);
        const days = greetingWindow.dayDelta(now, start);
        const dayName = days <= 0 ? "today" : days === 1 ? "tomorrow" : Qt.formatDate(start, "ddd").toLowerCase();
        if (ev.allDay)
            return days <= 0 ? "all day" : dayName;
        if (start <= now)
            return "now · ends " + greetingWindow.clockTime(end);
        const mins = Math.round((start - now) / 60000);
        if (mins < 60)
            return "in " + mins + "m";
        if (days === 0 && mins < 180)
            return "in " + greetingWindow.shortDuration(mins * 60);
        return (days === 0 ? "" : dayName + " ") + greetingWindow.clockTime(start);
    }

    readonly property int labAlerts: greetingWindow.labData && greetingWindow.labData.alerts ? greetingWindow.labData.alerts.critical + greetingWindow.labData.alerts.warning : 0
    readonly property color labColor: {
        const d = greetingWindow.labData;
        if (!d || !d.ok)
            return Qt.rgba(greetingWindow.contentFg.r, greetingWindow.contentFg.g, greetingWindow.contentFg.b, 0.4);
        if (d.nodes.ready < d.nodes.total || (d.alerts && d.alerts.critical > 0) || (d.flux && d.flux.failing.length > 0))
            return greetingWindow.badColor;
        if (greetingWindow.labAlerts > 0)
            return greetingWindow.warnColor;
        return greetingWindow.okColor;
    }
    readonly property string labText: {
        const d = greetingWindow.labData;
        if (!d)
            return "";
        if (!d.ok)
            return d.error || "cluster unreachable";
        const parts = [d.nodes.ready + "/" + d.nodes.total + " nodes"];
        if (d.flux)
            parts.push("flux " + d.flux.ready + "/" + d.flux.total);
        return parts.join(" · ");
    }
    readonly property string labDetail: {
        const d = greetingWindow.labData;
        if (!d || !d.ok)
            return "";
        if (d.alerts === null)
            return "alerts ?";
        if (greetingWindow.labAlerts === 0)
            return "no alerts";
        return greetingWindow.labAlerts + (greetingWindow.labAlerts === 1 ? " alert" : " alerts");
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

    visible: greetingWindow.themeReady && greetingWindow.enabled && greetingWindow.rested && greetingWindow.pose !== null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "transparent"

    mask: Region {
        item: clockGroup
        Region {
            item: statsGroup
        }
        Region {
            item: sysGroup
        }
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

    component InfoLine: Item {
        id: lineRoot
        property string label: ""
        property string primary: ""
        property string secondary: ""
        property string trailing: ""
        property color dotColor: greetingWindow.contentAccent
        property bool dotFilled: true
        property bool dotVisible: true
        property bool pulsing: false
        property int windowId: -1

        width: parent.width
        height: 26

        Text {
            id: lineLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            text: lineRoot.label
            color: Qt.rgba(greetingWindow.contentFg.r, greetingWindow.contentFg.g, greetingWindow.contentFg.b, 0.78)
            font {
                family: greetingWindow.barFont
                pixelSize: 13
                weight: Font.Medium
                letterSpacing: 1.5
            }
        }

        Rectangle {
            id: lineDot
            anchors.left: lineLabel.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            visible: lineRoot.dotVisible
            color: lineRoot.dotFilled ? lineRoot.dotColor : "transparent"
            border.width: lineRoot.dotFilled ? 0 : 1.5
            border.color: lineRoot.dotColor

            SequentialAnimation on opacity {
                running: lineRoot.pulsing && greetingWindow.motionActive
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation {
                    to: 0.25
                    duration: 900
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1
                    duration: 900
                    easing.type: Easing.InOutSine
                }
            }
        }

        Row {
            anchors.left: lineDot.right
            anchors.leftMargin: 10
            anchors.right: lineTrailing.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                id: linePrimary
                width: Math.min(implicitWidth, parent.width)
                text: lineRoot.primary
                color: greetingWindow.contentFg
                elide: Text.ElideRight
                font {
                    family: greetingWindow.barFont
                    pixelSize: 13
                    weight: Font.Medium
                }
            }

            Text {
                width: Math.max(0, parent.width - linePrimary.width - parent.spacing)
                visible: lineRoot.secondary !== ""
                text: lineRoot.secondary
                color: Qt.rgba(greetingWindow.contentFg.r, greetingWindow.contentFg.g, greetingWindow.contentFg.b, 0.6)
                elide: Text.ElideRight
                font {
                    family: greetingWindow.barFont
                    pixelSize: 13
                }
            }
        }

        Text {
            id: lineTrailing
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: lineRoot.trailing
            color: Qt.rgba(greetingWindow.contentFg.r, greetingWindow.contentFg.g, greetingWindow.contentFg.b, 0.78)
            font {
                family: greetingWindow.barFont
                pixelSize: 13
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: lineRoot.windowId >= 0
            cursorShape: Qt.PointingHandCursor
            onClicked: greetingWindow.niriService.focusWindow(lineRoot.windowId)
        }
    }

    Item {
        id: fadeRoot
        anchors.fill: parent
        opacity: greetingWindow.visible && !greetingWindow.dismissed ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 900
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: contentContainer
            readonly property real u: greetingWindow.compactProgress
            readonly property real sp: greetingWindow.splitProgress
            x: greetingWindow.pose ? (greetingWindow.split ? greetingWindow.splitGeom.left : greetingWindow.pose.x) : 24
            y: greetingWindow.pose ? (greetingWindow.split ? greetingWindow.splitGeom.top : greetingWindow.pose.y) : 24
            readonly property real bp: greetingWindow.bandProgress
            width: (1 - sp - bp) * (1048 + (greetingWindow.compactWidth + 48 - 1048) * u) + sp * greetingWindow.splitGeom.width + bp * (greetingWindow.bandWidth + 48)
            height: (1 - sp - bp) * (greetingWindow.wideInnerHeight + (greetingWindow.compactInnerHeight - greetingWindow.wideInnerHeight) * u + 48) + sp * greetingWindow.splitGeom.height + bp * (greetingWindow.bandHeight + 48)
            scale: greetingWindow.pose ? greetingWindow.pose.scale : 1
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

                Scrim {
                    target: clockGroup
                }

                Scrim {
                    target: sysGroup
                }

                Scrim {
                    target: statsGroup
                }

                Item {
                    id: clockGroup
                    readonly property real u: greetingWindow.compactProgress
                    readonly property real wideY: (greetingWindow.wideInnerHeight - greetingWindow.wideClockHeight) / 2

                    readonly property real sp: greetingWindow.splitProgress
                    x: sp * greetingWindow.splitGeom.clockX
                    width: 520 + (greetingWindow.compactWidth - 520) * u
                    height: greetingWindow.wideClockHeight + (greetingWindow.compactClockHeight - greetingWindow.wideClockHeight) * u
                    readonly property real bp: greetingWindow.bandProgress
                    y: (1 - sp - bp) * (1 - u) * (1 - u) * wideY + sp * greetingWindow.splitGeom.clockY

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

                Item {
                    id: statsAnchor
                    readonly property real u: greetingWindow.compactProgress
                    readonly property real wideY: (greetingWindow.wideInnerHeight - greetingWindow.statsHeight) / 2
                    readonly property real compactY: greetingWindow.compactClockHeight + 24
                    x: (1 - u) * (600 + 580 * u)
                    y: (1 - u) * wideY + u * compactY + 208 * u * (1 - u)
                }

                Column {
                    id: sysGroup
                    readonly property real sp: greetingWindow.splitProgress
                    readonly property real bp: greetingWindow.bandProgress
                    x: (1 - sp - bp) * statsAnchor.x + sp * greetingWindow.splitGeom.clockX + bp * (greetingWindow.splitClockWidth + greetingWindow.bandGap)
                    y: (1 - sp - bp) * statsAnchor.y + sp * (greetingWindow.splitGeom.clockY + greetingWindow.wideClockHeight + 24)
                    width: greetingWindow.compactWidth
                    height: greetingWindow.sysHeight
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

                    StatRow {
                        visible: greetingWindow.batteryShown
                        label: "BAT"
                        value: greetingWindow.batteryValue
                        amount: greetingWindow.powerService.chargePercent
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        opacity: 1 - sysGroup.sp - sysGroup.bp
                        color: Qt.rgba(greetingWindow.contentFg.r, greetingWindow.contentFg.g, greetingWindow.contentFg.b, 0.18)
                    }
                }

                Column {
                    id: statsGroup
                    readonly property real sp: greetingWindow.splitProgress
                    readonly property real bp: greetingWindow.bandProgress
                    x: (1 - sp - bp) * statsAnchor.x + sp * greetingWindow.splitGeom.statsX + bp * (greetingWindow.splitClockWidth + greetingWindow.bandGap * 2 + greetingWindow.bandColumnWidth)
                    y: (1 - sp - bp) * (statsAnchor.y + greetingWindow.sysBlock) + sp * greetingWindow.splitGeom.statsY
                    width: greetingWindow.compactWidth
                    height: greetingWindow.band ? greetingWindow.bandRestHeight : greetingWindow.statsHeight - greetingWindow.sysBlock
                    spacing: 8

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

                    Rectangle {
                        visible: greetingWindow.infoLineCount > 0
                        width: parent.width
                        height: 1
                        color: Qt.rgba(greetingWindow.contentFg.r, greetingWindow.contentFg.g, greetingWindow.contentFg.b, 0.18)
                    }

                    InfoLine {
                        visible: greetingWindow.nextEvent !== null
                        label: "NXT"
                        dotVisible: false
                        primary: greetingWindow.nextEvent ? greetingWindow.nextEvent.title : ""
                        trailing: greetingWindow.nextEvent ? greetingWindow.eventWhen(greetingWindow.nextEvent, greetingWindow.now) : ""
                    }

                    InfoLine {
                        visible: greetingWindow.labData !== null
                        label: "LAB"
                        dotColor: greetingWindow.labColor
                        primary: greetingWindow.labText
                        trailing: greetingWindow.labDetail
                    }

                    Repeater {
                        model: greetingWindow.agentLines

                        delegate: InfoLine {
                            required property var modelData
                            required property int index
                            label: index === 0 ? "AGT" : ""
                            windowId: modelData.id
                            dotFilled: modelData.state !== "idle"
                            pulsing: modelData.state === "working"
                            dotColor: modelData.state === "idle" ? Qt.rgba(greetingWindow.contentFg.r, greetingWindow.contentFg.g, greetingWindow.contentFg.b, 0.6) : greetingWindow.contentAccent
                            primary: modelData.project || modelData.agent
                            secondary: modelData.task || modelData.agent
                            trailing: modelData.state
                        }
                    }

                    InfoLine {
                        visible: greetingWindow.agentOverflow > 0
                        dotVisible: false
                        primary: ""
                        secondary: "+" + greetingWindow.agentOverflow + " more"
                    }

                    BluetoothDevices {
                        visible: connectedDevices.length > 0 && !greetingWindow.band
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
