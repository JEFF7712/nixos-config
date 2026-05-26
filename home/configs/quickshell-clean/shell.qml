import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property color themeFg: "#ffffff"
    property color themeBg: "#662a2a2a"
    property color popupBg: "#cc2a2a2a"
    property color themeRawBg: "#141414"
    property color themeAccent: "#ffffff"
    property color themeSecond: "#e8e8e8"
    property color themeWarm: "#e6dcc6"
    property color themeFresh: "#d6eadc"

    property int barRadius: 15
    property int barHeight: 44
    property int barMargin: 10
    property bool showClockDate: true
    property bool showWorkspaceNumbers: true
    property string barFont: "JetBrainsMono Nerd Font"
    property bool flatMode: false
    property color dividerColor: "#1affffff"
    property color barBorderColor: "#3dffffff"
    property color barInnerHighlight: "#0fffffff"
    property color pillBg: "#0affffff"
    property color pillBorder: "#14ffffff"

    readonly property int popupTopMargin: barMargin + barHeight + 10

    function applyTheme(theme) {
        if (!theme) return
        if (theme.fg)                root.themeFg            = theme.fg
        if (theme.bg)                root.themeBg            = theme.bg
        if (theme.popupBg)           root.popupBg            = theme.popupBg
        if (theme.rawBg)             root.themeRawBg         = theme.rawBg
        if (theme.accent)            root.themeAccent        = theme.accent
        if (theme.second)            root.themeSecond        = theme.second
        if (theme.warm)              root.themeWarm          = theme.warm
        if (theme.fresh)             root.themeFresh         = theme.fresh
        if (theme.barRadius)         root.barRadius          = parseInt(theme.barRadius)
        if (theme.barHeight)         root.barHeight          = parseInt(theme.barHeight)
        if (theme.barMargin)         root.barMargin          = parseInt(theme.barMargin)
        if (theme.showClockDate)     root.showClockDate      = theme.showClockDate === "true"
        if (theme.showWorkspaceNumbers) root.showWorkspaceNumbers = theme.showWorkspaceNumbers === "true"
        if (theme.barFont)           root.barFont            = theme.barFont
        if (theme.flatMode)          root.flatMode           = theme.flatMode === "true"
        if (theme.dividerColor)      root.dividerColor       = theme.dividerColor
        if (theme.barBorder)         root.barBorderColor     = theme.barBorder
        if (theme.barInnerHighlight) root.barInnerHighlight  = theme.barInnerHighlight
        if (theme.pillBg)            root.pillBg             = theme.pillBg
        if (theme.pillBorder)        root.pillBorder         = theme.pillBorder
    }

    Process {
        id: themeLoader
        running: true
        command: ["sh", "-c",
            "p=\"$HOME/.config/desktop-profiles\";" +
            "[ -f \"$p/active\" ] || exit 0;" +
            "cat \"$p/$(cat $p/active)/quickshell-theme.json\" 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = this.text.trim()
                if (!txt) return
                try {
                    root.applyTheme(JSON.parse(txt))
                } catch (e) {
                    console.warn("quickshell-theme.json parse failed:", e)
                }
            }
        }
    }

    readonly property bool anyPopupShown:
        wifiPopup.shown || bluetoothPopup.shown || batteryPopup.shown
        || calendarPopup.shown || notificationsPopup.shown || systemPopup.shown
        || mediaPopup.shown

    function showOnly(target) {
        const popups = [
            wifiPopup, bluetoothPopup, batteryPopup,
            calendarPopup, notificationsPopup, systemPopup, mediaPopup
        ]
        for (const p of popups) {
            if (p !== target) p.close()
        }
        target.toggle()
    }

    function closeAll() {
        wifiPopup.close()
        bluetoothPopup.close()
        batteryPopup.close()
        calendarPopup.close()
        notificationsPopup.close()
        systemPopup.close()
        mediaPopup.close()
    }

    Topbar {
        id: topbar
        themeFg: root.themeFg
        themeBg: root.themeBg
        themeRawBg: root.themeRawBg
        themeAccent: root.themeAccent
        themeSecond: root.themeSecond
        themeWarm: root.themeWarm
        themeFresh: root.themeFresh
        barRadius: root.barRadius
        barHeight: root.barHeight
        barMargin: root.barMargin
        showClockDate: root.showClockDate
        showWorkspaceNumbers: root.showWorkspaceNumbers
        barFont: root.barFont
        flatMode: root.flatMode
        dividerColor: root.dividerColor
        barBorderColor: root.barBorderColor
        barInnerHighlight: root.barInnerHighlight
        pillBg: root.pillBg
        pillBorder: root.pillBorder
        notificationCount: notificationsPopup.unreadCount

        onWifiClicked: root.showOnly(wifiPopup)
        onBluetoothClicked: root.showOnly(bluetoothPopup)
        onBatteryClicked: root.showOnly(batteryPopup)
        onClockClicked: root.showOnly(calendarPopup)
        onNotificationsClicked: root.showOnly(notificationsPopup)
        onSystemClicked: root.showOnly(systemPopup)
        onMediaClicked: root.showOnly(mediaPopup)
    }

    WifiPopup {
        id: wifiPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        topMargin: root.popupTopMargin
    }

    BluetoothPopup {
        id: bluetoothPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        topMargin: root.popupTopMargin
    }

    BatteryPopup {
        id: batteryPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        topMargin: root.popupTopMargin
        powerProfile: topbar.powerProfile
        cpuUsage: topbar.cpuUsage
        ramUsage: topbar.ramUsage
        diskUsage: topbar.diskUsage
    }

    CalendarPopup {
        id: calendarPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        topMargin: root.popupTopMargin
    }

    NotificationsPopup {
        id: notificationsPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        topMargin: root.popupTopMargin
    }

    SystemPopup {
        id: systemPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        topMargin: root.popupTopMargin
    }

    MediaPopup {
        id: mediaPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        topMargin: root.popupTopMargin
        status: topbar.mediaStatus
        track: topbar.mediaTitle
        artist: topbar.mediaArtist
        album: topbar.mediaAlbum
        artUrl: topbar.mediaArtUrl
    }

    PanelWindow {
        id: catcher
        visible: root.anyPopupShown
        anchors { top: true; bottom: true; left: true; right: true }
        margins { top: 64 }
        exclusiveZone: -1
        color: "transparent"
        WlrLayershell.namespace: "quickshell-clean-catcher"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeAll()
        }
    }
}
