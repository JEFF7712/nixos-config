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

    property string cpuUsage: "-"
    property string ramUsage: "-"
    property string volumeLevel: "-"
    property string brightnessLevel: "-"
    property string networkIcon: "󰖪"
    property string batteryPercent: ""
    property string batteryIcon: "󰁹"
    property string powerProfile: "balanced"
    property string activeTitle: "no active window"
    property int activeWorkspace: 1
    property var occupiedWorkspaces: ({})

    signal wifiClicked()
    signal bluetoothClicked()
    signal batteryClicked()
    signal clockClicked()
    signal notificationsClicked()
    signal systemClicked()

    readonly property var powerProfileOrder: ["power-saver", "balanced", "performance"]
    readonly property var powerProfileIcons: ({
        "power-saver": "󰌪",
        "balanced": "󰾅",
        "performance": "󱐋"
    })

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    function cyclePowerProfile() {
        const order = topbarWindow.powerProfileOrder
        const idx = order.indexOf(topbarWindow.powerProfile)
        const next = order[(idx + 1) % order.length]
        topbarWindow.run("powerprofilesctl set " + next)
        topbarWindow.powerProfile = next
        statsProc.running = true
    }

    function adjustVolume(delta) {
        const step = 5
        const arg = delta > 0 ? (step + "%+") : (step + "%-")
        topbarWindow.run("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + arg)
        statsProc.running = true
    }

    function adjustBrightness(delta) {
        const step = 5
        const arg = delta > 0 ? (step + "%+") : (step + "%-")
        topbarWindow.run("brightnessctl set " + arg)
        statsProc.running = true
    }

    WlrLayershell.namespace: "quickshell-clean-topbar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; left: true; right: true }
    margins { top: 10; left: 10; right: 10 }
    implicitHeight: 44
    exclusiveZone: 54
    color: "transparent"

    Process {
        id: statsProc
        command: ["sh", "-c",
            "cpu=$(awk 'NR==1{u=$2+$4; t=$2+$3+$4+$5; getline; u2=$2+$4; t2=$2+$3+$4+$5; if (t2>t) printf \"%d\", (u2-u)*100/(t2-t); else printf \"0\"}' <(cat /proc/stat; sleep 0.2; cat /proc/stat));" +
            "mem=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2; printf \"%.1fG\", (t-a)/1048576}' /proc/meminfo);" +
            "vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}');" +
            "br=$(brightnessctl -m 2>/dev/null | awk -F, '{print $4}' | tr -d '%');" +
            "net=$(nmcli -t -f STATE general 2>/dev/null);" +
            "bc=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1);" +
            "bs=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1);" +
            "pp=$(powerprofilesctl get 2>/dev/null);" +
            "echo \"$cpu|$mem|$vol|$br|$net|$bc|$bs|$pp\""
        ]
        property string buffer: ""
        stdout: SplitParser { onRead: (data) => statsProc.buffer += data }
        onExited: {
            const p = statsProc.buffer.trim().split("|")
            if (p.length >= 7) {
                topbarWindow.cpuUsage = p[0] !== "" ? p[0] + "%" : "-"
                topbarWindow.ramUsage = p[1] !== "" ? p[1] : "-"
                topbarWindow.volumeLevel = p[2] !== "" ? p[2] + "%" : "-"
                topbarWindow.brightnessLevel = p[3] !== "" ? p[3] + "%" : "-"
                topbarWindow.networkIcon = p[4] === "connected" ? "󰖩" : "󰖪"
                const cap = parseInt(p[5])
                if (!isNaN(cap)) {
                    topbarWindow.batteryPercent = cap + "%"
                    topbarWindow.batteryIcon =
                        p[6] === "Charging" ? "󰂄" :
                        cap > 90 ? "󰁹" : cap > 70 ? "󰂀" :
                        cap > 40 ? "󰁾" : cap > 10 ? "󰁼" : "󰂎"
                }
                if (p.length >= 8 && p[7] !== "") {
                    topbarWindow.powerProfile = p[7]
                }
            }
            statsProc.buffer = ""
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
        id: workspacesProc
        command: ["sh", "-c", "niri msg -j workspaces 2>/dev/null || true"]
        property string buffer: ""
        stdout: SplitParser { onRead: (data) => workspacesProc.buffer += data }
        onExited: {
            try {
                const workspaces = JSON.parse(workspacesProc.buffer || "[]")
                const occupied = {}
                let active = topbarWindow.activeWorkspace
                for (const ws of workspaces) {
                    const idx = ws.idx || ws.id
                    if (idx === undefined) continue
                    occupied[idx] = true
                    if (ws.is_focused || ws.is_active) active = idx
                }
                topbarWindow.occupiedWorkspaces = occupied
                topbarWindow.activeWorkspace = active
            } catch (e) {}
            workspacesProc.buffer = ""
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
        stdout: SplitParser { onRead: (data) => titleProc.buffer += data }
        onExited: {
            try {
                const win = JSON.parse(titleProc.buffer || "{}")
                topbarWindow.activeTitle = win.title || win.app_id || "no active window"
            } catch (e) {
                topbarWindow.activeTitle = "no active window"
            }
            titleProc.buffer = ""
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: titleProc.running = true
    }

    Rectangle {
        anchors.fill: parent
        radius: 15
        color: topbarWindow.themeBg
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.24)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        Item {
            id: workspacesArea
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14
            width: wsRow.implicitWidth
            height: 30

            Row {
                id: wsRow
                spacing: 8
                anchors.top: parent.top

                Repeater {
                    model: 10
                    delegate: WorkspacePill { wsId: index + 1 }
                }
            }

            Rectangle {
                id: wsIndicator
                width: 18
                height: 2
                radius: 1
                color: topbarWindow.themeAccent
                anchors.bottom: parent.bottom
                opacity: 0.9
                x: (topbarWindow.activeWorkspace - 1) * 36 + 5
                Behavior on x { SpringAnimation { spring: 3.5; damping: 0.32; mass: 0.6 } }
            }
        }

        Row {
            id: rightGroup
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 12
            spacing: 6

            StatPill { icon: "󰻠"; value: topbarWindow.cpuUsage; tint: topbarWindow.themeWarm }
            StatPill { icon: "󰍛"; value: topbarWindow.ramUsage; tint: topbarWindow.themeFresh }
            StatPill {
                icon: "󰕾"
                value: topbarWindow.volumeLevel
                tint: topbarWindow.themeAccent
                onActivated: topbarWindow.run("pavucontrol")
                onScrolled: (delta) => topbarWindow.adjustVolume(delta)
            }
            StatPill {
                icon: "󰃞"
                value: topbarWindow.brightnessLevel
                tint: topbarWindow.themeWarm
                onScrolled: (delta) => topbarWindow.adjustBrightness(delta)
            }
            StatPill {
                icon: topbarWindow.networkIcon
                value: ""
                tint: topbarWindow.themeSecond
                onActivated: topbarWindow.wifiClicked()
            }
            StatPill {
                icon: "󰂯"
                value: ""
                tint: topbarWindow.themeSecond
                onActivated: topbarWindow.bluetoothClicked()
            }
            StatPill {
                icon: topbarWindow.powerProfileIcons[topbarWindow.powerProfile] || "󰾅"
                value: ""
                tint: topbarWindow.powerProfile === "performance"
                    ? topbarWindow.themeWarm
                    : topbarWindow.powerProfile === "power-saver"
                        ? topbarWindow.themeFresh
                        : topbarWindow.themeAccent
                onActivated: topbarWindow.cyclePowerProfile()
            }
            StatPill {
                icon: topbarWindow.batteryIcon
                value: topbarWindow.batteryPercent
                tint: topbarWindow.themeAccent
                onActivated: topbarWindow.batteryClicked()
            }
            StatPill {
                icon: "󰂚"
                value: ""
                tint: topbarWindow.themeSecond
                onActivated: topbarWindow.notificationsClicked()
            }
            StatPill {
                icon: "󰐥"
                value: ""
                tint: topbarWindow.themeAccent
                onActivated: topbarWindow.systemClicked()
            }
        }

        Item {
            id: clockArea
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: clockColumn.implicitWidth + 16
            height: clockColumn.implicitHeight + 8

            ColumnLayout {
                id: clockColumn
                anchors.centerIn: parent
                spacing: -3

                Text {
                    id: clockTime
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatTime(new Date(), "h:mm AP")
                    color: topbarWindow.themeAccent
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 17; weight: Font.Light; letterSpacing: 1.2 }
                    Timer {
                        interval: 10000
                        running: true
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: {
                            clockTime.text = Qt.formatTime(new Date(), "h:mm AP")
                            clockDate.text = Qt.formatDate(new Date(), "ddd d MMM").toUpperCase()
                        }
                    }
                }

                Text {
                    id: clockDate
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDate(new Date(), "ddd d MMM").toUpperCase()
                    color: topbarWindow.themeSecond
                    opacity: 0.6
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 8; letterSpacing: 0.8; weight: Font.Medium }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: topbarWindow.clockClicked()
            }
        }

        RowLayout {
            anchors.left: workspacesArea.right
            anchors.right: clockArea.left
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
                    NumberAnimation { to: 0.45; duration: 1400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                }
            }

            Text {
                Layout.fillWidth: true
                text: topbarWindow.activeTitle
                color: topbarWindow.activeTitle === "no active window"
                    ? Qt.rgba(topbarWindow.themeFg.r, topbarWindow.themeFg.g, topbarWindow.themeFg.b, 0.4)
                    : topbarWindow.themeFg
                elide: Text.ElideRight
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12; weight: Font.Medium; letterSpacing: 0.3 }
                Behavior on color { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }
        }
    }

    component WorkspacePill: Item {
        id: wsRoot
        property int wsId: 1
        readonly property bool isActive: topbarWindow.activeWorkspace === wsId
        readonly property bool isOccupied: topbarWindow.occupiedWorkspaces[wsId] === true

        width: 28
        height: 24

        Rectangle {
            id: wsBase
            anchors.fill: parent
            radius: 9
            color: wsMouse.pressed
                ? Qt.rgba(1, 1, 1, 0.12)
                : wsMouse.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.08)
                    : Qt.rgba(1, 1, 1, wsRoot.isOccupied ? 0.05 : 0.025)
            Behavior on color { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }

            border.width: 1
            border.color: wsRoot.isActive
                ? "transparent"
                : wsMouse.containsMouse
                    ? Qt.rgba(topbarWindow.themeAccent.r, topbarWindow.themeAccent.g, topbarWindow.themeAccent.b, 0.55)
                    : Qt.rgba(1, 1, 1, wsRoot.isOccupied ? 0.16 : 0.06)
            Behavior on border.color { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }

            scale: wsMouse.pressed ? 0.94 : (wsMouse.containsMouse ? 1.06 : 1.0)
            Behavior on scale { SpringAnimation { spring: 3; damping: 0.55; mass: 0.8 } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: topbarWindow.themeAccent
                opacity: wsRoot.isActive ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutQuart } }
            }

            Text {
                anchors.centerIn: parent
                text: wsRoot.wsId
                color: wsRoot.isActive
                    ? topbarWindow.themeRawBg
                    : wsRoot.isOccupied
                        ? topbarWindow.themeFg
                        : Qt.rgba(topbarWindow.themeFg.r, topbarWindow.themeFg.g, topbarWindow.themeFg.b, 0.32)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: wsRoot.isActive ? 12 : 11
                    weight: wsRoot.isActive ? Font.Bold : Font.Medium
                }
                scale: wsMouse.pressed ? 0.9 : (wsMouse.containsMouse ? 1.08 : 1.0)
                Behavior on scale { SpringAnimation { spring: 4; damping: 0.5; mass: 0.7 } }
                Behavior on color { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: wsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: topbarWindow.run("niri msg action focus-workspace " + wsRoot.wsId)
        }
    }

    component StatPill: Item {
        id: statRoot
        property string icon
        property string value
        property color tint
        signal activated()
        signal scrolled(int delta)

        width: statContent.implicitWidth + 22
        height: 26

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: statMouse.pressed
                ? Qt.rgba(1, 1, 1, 0.12)
                : statMouse.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.08)
                    : Qt.rgba(1, 1, 1, 0.04)
            Behavior on color { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }

            border.width: 1
            border.color: statMouse.containsMouse
                ? Qt.rgba(statRoot.tint.r, statRoot.tint.g, statRoot.tint.b, 0.55)
                : Qt.rgba(1, 1, 1, 0.08)
            Behavior on border.color { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }

            scale: statMouse.pressed ? 0.94 : (statMouse.containsMouse ? 1.06 : 1.0)
            Behavior on scale { SpringAnimation { spring: 3; damping: 0.55; mass: 0.8 } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: statRoot.tint
                opacity: statMouse.containsMouse ? 0.18 : 0.0
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            }

            RowLayout {
                id: statContent
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: statRoot.icon
                    color: statMouse.containsMouse
                        ? statRoot.tint
                        : Qt.rgba(topbarWindow.themeFg.r, topbarWindow.themeFg.g, topbarWindow.themeFg.b, 0.75)
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                    scale: statMouse.pressed ? 0.9 : (statMouse.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { SpringAnimation { spring: 4; damping: 0.5; mass: 0.7 } }
                    Behavior on color { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }

                Text {
                    text: statRoot.value
                    visible: statRoot.value !== ""
                    color: topbarWindow.themeFg
                    opacity: 0.85
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; weight: Font.Medium }
                }
            }
        }

        MouseArea {
            id: statMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: statRoot.activated()
            onWheel: (event) => {
                statRoot.scrolled(event.angleDelta.y)
                event.accepted = true
            }
        }
    }
}
