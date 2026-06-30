import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: topbarWindow

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

    property string cpuUsage: "-"
    property string ramUsage: "-"
    property string diskUsage: "-"
    property string volumeLevel: "-"
    property bool volumeMuted: false
    property string networkIcon: "󰖪"
    property string batteryPercent: ""
    property string batteryIcon: "󰁹"
    property string powerProfile: "balanced"
    property string activeTitle: "no active window"
    property int notificationCount: 0
    property string mediaStatus: ""
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaAlbum: ""
    property string mediaArtUrl: ""
    property var cavaValues: []
    property bool cavaRequested: false
    property int activeWorkspace: 1
    property var occupiedWorkspaces: ({})
    property var workspaceList: []

    signal wifiClicked
    signal volumeClicked
    signal bluetoothClicked
    signal batteryClicked
    signal clockClicked
    signal notificationsClicked
    signal systemClicked
    signal mediaClicked

    readonly property var powerProfileOrder: ["power-saver", "balanced", "performance"]

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function setPowerProfile(name) {
        topbarWindow.run("powerprofilesctl set " + name);
        topbarWindow.powerProfile = name;
        statsProc.running = true;
    }

    function cyclePowerProfile() {
        const order = topbarWindow.powerProfileOrder;
        const idx = order.indexOf(topbarWindow.powerProfile);
        topbarWindow.setPowerProfile(order[(idx + 1) % order.length]);
    }

    function adjustVolume(delta) {
        const step = 2;
        const arg = delta > 0 ? (step + "%+") : (step + "%-");
        topbarWindow.run("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + arg);
    }

    function setVolume(percent) {
        const clamped = Math.max(0, Math.min(100, percent));
        topbarWindow.volumeLevel = clamped + "%";
        topbarWindow.run("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + clamped + "%");
    }

    function volumePercent() {
        const parsed = parseInt(String(topbarWindow.volumeLevel).replace("%", ""));
        return isNaN(parsed) ? 0 : Math.max(0, Math.min(100, parsed));
    }

    function volumeIcon() {
        const percent = topbarWindow.volumePercent();
        if (topbarWindow.volumeMuted || percent <= 0)
            return "󰖁";
        if (percent < 34)
            return "󰕿";
        if (percent < 67)
            return "󰖀";
        return "󰕾";
    }

    function adjustMedia(delta) {
        topbarWindow.run("playerctl " + (delta > 0 ? "next" : "previous"));
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

    Process {
        id: statsProc
        command: ["sh", "-c", "cpu=$(awk '/^cpu / { if (!have) { u=$2+$4; t=$2+$3+$4+$5; have=1 } else { u2=$2+$4; t2=$2+$3+$4+$5; if (t2>t) printf \"%d\", (u2-u)*100/(t2-t); else printf \"0\"; exit } }' <(cat /proc/stat; sleep 0.2; cat /proc/stat));" + "mem=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2; printf \"%.1fG\", (t-a)/1048576}' /proc/meminfo);" + "dsk=$(df -P / 2>/dev/null | awk 'NR==2{gsub(\"%\",\"\",$5); print $5}');" + "vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}');" + "net=$(nmcli -t -f STATE general 2>/dev/null);" + "bc=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1);" + "bs=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1);" + "pp=$(powerprofilesctl get 2>/dev/null);" + "echo \"$cpu|$mem|$dsk|$vol|$net|$bc|$bs|$pp\""]
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => statsProc.buffer += data
        }
        onExited: {
            const p = statsProc.buffer.trim().split("|");
            if (p.length >= 7) {
                topbarWindow.cpuUsage = p[0] !== "" ? p[0] + "%" : "-";
                topbarWindow.ramUsage = p[1] !== "" ? p[1] : "-";
                topbarWindow.diskUsage = p[2] !== "" ? p[2] + "%" : "-";
                topbarWindow.volumeLevel = p[3] !== "" ? p[3] + "%" : "-";
                topbarWindow.networkIcon = p[4] === "connected" ? "󰖩" : "󰖪";
                const cap = parseInt(p[5]);
                if (!isNaN(cap)) {
                    topbarWindow.batteryPercent = cap + "%";
                    topbarWindow.batteryIcon = p[6] === "Charging" ? "󰂄" : cap > 90 ? "󰁹" : cap > 70 ? "󰂀" : cap > 40 ? "󰁾" : cap > 10 ? "󰁼" : "󰂎";
                }
                if (p.length >= 8 && p[7] !== "") {
                    topbarWindow.powerProfile = p[7];
                }
            }
            statsProc.buffer = "";
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statsProc.running = true
    }

    Process {
        id: volumeProbe
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{vol=int($2*100); mute=index($0,\"MUTED\")>0?\"m\":\"a\"; print vol\"|\"mute}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("|");
                if (parts.length === 2) {
                    topbarWindow.volumeLevel = parts[0] !== "" ? parts[0] + "%" : "-";
                    topbarWindow.volumeMuted = parts[1] === "m";
                }
            }
        }
    }

    Timer {
        id: volumeDebounce
        interval: 50
        repeat: false
        onTriggered: volumeProbe.running = true
    }

    // pw-mon (pipewire-native) emits param-change events on every volume/mute
    // change, regardless of which tool triggered it. setpriv --pdeathsig ensures
    // it dies with quickshell instead of orphaning on pkill/profile-switch.
    Process {
        id: volumeSubscribeProc
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "--", "stdbuf", "-oL", "pw-mon"]
        stdout: SplitParser {
            onRead: data => {
                if (data.indexOf("Props:volume") !== -1 || data.indexOf("Props:mute") !== -1 || data.indexOf("Props:channelVolumes") !== -1) {
                    volumeDebounce.restart();
                }
            }
        }
    }

    // setpriv --pdeathsig: playerctl --follow does not exit when quickshell's
    // stdout pipe closes (only on next write, which never comes while idle), so
    // without this it orphans on every pkill/profile-switch and piles up.
    // sh exec replaces itself with playerctl, so the pdeathsig applies to it.
    Process {
        id: mediaFollowProc
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "--", "sh", "-c", "exec playerctl --follow metadata --format '{{status}}@@@{{xesam:title}}@@@{{xesam:artist}}@@@{{xesam:album}}@@@{{mpris:artUrl}}' 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                const parts = data.split("@@@");
                topbarWindow.mediaStatus = parts[0] || "";
                topbarWindow.mediaTitle = parts[1] || "";
                topbarWindow.mediaArtist = parts[2] || "";
                topbarWindow.mediaAlbum = parts[3] || "";
                topbarWindow.mediaArtUrl = parts[4] || "";
            }
        }
    }

    // cava raw-output visualizer feeding the centered media module. Only runs
    // while media is actually playing to avoid idle CPU. setpriv --pdeathsig so
    // it dies with quickshell rather than orphaning on pkill/profile-switch.
    readonly property string cavaConfigPath: Qt.resolvedUrl("cava-bar.conf").toString().replace("file://", "")
    Process {
        id: cavaProc
        running: topbarWindow.mediaStatus === "Playing" && (topbarWindow.showMedia || topbarWindow.cavaRequested)
        command: ["setpriv", "--pdeathsig", "TERM", "--", "cava", "-p", topbarWindow.cavaConfigPath]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                const parts = data.split(";");
                const vals = [];
                for (let i = 0; i < parts.length; i++) {
                    if (parts[i] === "")
                        continue;
                    const n = parseInt(parts[i]);
                    if (!isNaN(n))
                        vals.push(n);
                }
                if (vals.length > 0)
                    topbarWindow.cavaValues = vals;
            }
        }
        onRunningChanged: {
            if (!running)
                topbarWindow.cavaValues = [];
        }
    }

    Process {
        id: workspacesProc
        command: ["sh", "-c", "niri msg -j workspaces 2>/dev/null || true"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => workspacesProc.buffer += data
        }
        onExited: {
            try {
                const workspaces = JSON.parse(workspacesProc.buffer || "[]");
                const occupied = {};
                const list = [];
                let active = topbarWindow.activeWorkspace;
                for (const ws of workspaces) {
                    const idx = ws.idx || ws.id;
                    if (idx === undefined)
                        continue;
                    list.push(idx);
                    if (ws.active_window_id !== null && ws.active_window_id !== undefined) {
                        occupied[idx] = true;
                    }
                    if (ws.is_focused || ws.is_active)
                        active = idx;
                }
                list.sort((a, b) => a - b);
                topbarWindow.workspaceList = list;
                topbarWindow.occupiedWorkspaces = occupied;
                topbarWindow.activeWorkspace = active;
            } catch (e) {}
            workspacesProc.buffer = "";
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: workspacesProc.running = true
    }

    Process {
        id: titleProc
        command: ["sh", "-c", "niri msg -j focused-window 2>/dev/null || true"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => titleProc.buffer += data
        }
        onExited: {
            try {
                const win = JSON.parse(titleProc.buffer || "{}");
                topbarWindow.activeTitle = win.title || win.app_id || "no active window";
            } catch (e) {
                topbarWindow.activeTitle = "no active window";
            }
            titleProc.buffer = "";
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: titleProc.running = true
    }

    Process {
        id: niriEventStream
        running: true
        command: ["sh", "-c", "niri msg event-stream 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                if (data.indexOf("Workspace") !== -1) {
                    workspacesProc.running = true;
                }
                if (data.indexOf("Window") !== -1) {
                    titleProc.running = true;
                }
            }
        }
    }

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
                    model: topbarWindow.workspaceList
                    delegate: WorkspacePill {
                        wsId: modelData
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
                x: (topbarWindow.activeWorkspace - 1) * 36 + 5
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
                value: (topbarWindow.volumeMuted || topbarWindow.volumeLevel === "100%" || topbarWindow.volumeLevel === "0%") ? "" : topbarWindow.volumeLevel
                tint: topbarWindow.volumeMuted ? Qt.rgba(topbarWindow.themeFg.r, topbarWindow.themeFg.g, topbarWindow.themeFg.b, 0.4) : topbarWindow.themeAccent
                onActivated: topbarWindow.volumeClicked()
                onMiddleClicked: topbarWindow.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                onRightClicked: topbarWindow.run("pavucontrol")
                onScrolled: delta => topbarWindow.adjustVolume(delta)
            }
            StatPill {
                visible: topbarWindow.showNetwork
                icon: topbarWindow.networkIcon
                value: ""
                tint: topbarWindow.themeSecond
                onActivated: topbarWindow.wifiClicked()
                onRightClicked: topbarWindow.run("kitty -e sudo nmtui")
            }
            StatPill {
                visible: topbarWindow.showBluetooth
                icon: "󰂯"
                value: ""
                tint: topbarWindow.themeSecond
                onActivated: topbarWindow.bluetoothClicked()
                onRightClicked: topbarWindow.run("blueman-manager")
            }
            StatPill {
                visible: topbarWindow.showBattery
                icon: topbarWindow.batteryIcon
                value: topbarWindow.batteryPercent === "100%" ? "" : topbarWindow.batteryPercent
                tint: topbarWindow.themeAccent
                onActivated: topbarWindow.batteryClicked()
                onRightClicked: topbarWindow.cyclePowerProfile()
                onScrolled: delta => {
                    const order = topbarWindow.powerProfileOrder;
                    const idx = order.indexOf(topbarWindow.powerProfile);
                    const next = (idx + (delta > 0 ? 1 : -1) + order.length) % order.length;
                    topbarWindow.setPowerProfile(order[next]);
                }
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
                onRightClicked: topbarWindow.run("lock-screen")
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
            id: mediaModule
            visible: topbarWindow.showMedia && topbarWindow.mediaStatus !== "" && topbarWindow.mediaStatus !== "Stopped"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            readonly property bool flat: topbarWindow.flatMode
            readonly property bool playing: topbarWindow.mediaStatus === "Playing"
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
                radius: mediaModule.flat ? 0 : 10
                color: mediaMouse.pressed ? Qt.rgba(1, 1, 1, 0.12) : mediaMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : topbarWindow.pillBg
                Behavior on color {
                    ColorAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                border.width: mediaModule.flat ? 0 : 1
                border.color: mediaMouse.containsMouse ? Qt.rgba(mediaModule.tint.r, mediaModule.tint.g, mediaModule.tint.b, 0.55) : topbarWindow.pillBorder
                Behavior on border.color {
                    ColorAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                scale: mediaModule.flat ? 1.0 : (mediaMouse.pressed ? 0.94 : 1.0)
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
                    color: mediaModule.tint
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
                        text: mediaModule.playing ? "󰏤" : "󰐊"
                        color: mediaMouse.containsMouse ? mediaModule.tint : Qt.rgba(topbarWindow.themeFg.r, topbarWindow.themeFg.g, topbarWindow.themeFg.b, 0.75)
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
                        text: topbarWindow.mediaTitle.length > 26 ? topbarWindow.mediaTitle.substring(0, 25) + "…" : topbarWindow.mediaTitle
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
                        visible: mediaModule.playing && topbarWindow.cavaValues.length > 0

                        Repeater {
                            model: topbarWindow.cavaValues
                            delegate: Rectangle {
                                width: 2
                                radius: 1
                                anchors.bottom: parent.bottom
                                height: Math.max(2, Math.min(14, (modelData / 100) * 14))
                                color: mediaModule.tint
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
                        topbarWindow.run("playerctl play-pause");
                    else
                        topbarWindow.mediaClicked();
                }
                onWheel: event => {
                    topbarWindow.adjustMedia(event.angleDelta.y);
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
        readonly property bool isActive: topbarWindow.activeWorkspace === wsId
        readonly property bool isOccupied: topbarWindow.occupiedWorkspaces[wsId] === true
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
            onClicked: topbarWindow.run("niri msg action focus-workspace " + wsRoot.wsId)
            onWheel: event => {
                const cmd = event.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down";
                topbarWindow.run("niri msg action " + cmd);
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
