import QtQuick
import Quickshell
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
    }

    BluetoothPopup {
        id: bluetoothPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
    }

    BatteryPopup {
        id: batteryPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        powerProfile: topbar.powerProfile
        cpuUsage: topbar.cpuUsage
        ramUsage: topbar.ramUsage
    }

    CalendarPopup {
        id: calendarPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
    }

    NotificationsPopup {
        id: notificationsPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
    }

    SystemPopup {
        id: systemPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
    }

    MediaPopup {
        id: mediaPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
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
