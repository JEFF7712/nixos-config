import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    property color themeFg: "#ffffff"
    property color themeBg: "#662a2a2a"
    property color themeRawBg: "#141414"
    property color themeAccent: "#ffffff"
    property color themeSecond: "#e8e8e8"
    property color themeWarm: "#e6dcc6"
    property color themeFresh: "#d6eadc"

    readonly property bool anyPopupShown:
        wifiPopup.shown || bluetoothPopup.shown || batteryPopup.shown

    function showOnly(target) {
        const popups = [wifiPopup, bluetoothPopup, batteryPopup]
        for (const p of popups) {
            if (p !== target) p.close()
        }
        target.toggle()
    }

    function closeAll() {
        wifiPopup.close()
        bluetoothPopup.close()
        batteryPopup.close()
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

        onWifiClicked: root.showOnly(wifiPopup)
        onBluetoothClicked: root.showOnly(bluetoothPopup)
        onBatteryClicked: root.showOnly(batteryPopup)
    }

    WifiPopup {
        id: wifiPopup
        themeFg: root.themeFg
        themeBg: root.themeBg
        themeAccent: root.themeAccent
    }

    BluetoothPopup {
        id: bluetoothPopup
        themeFg: root.themeFg
        themeBg: root.themeBg
        themeAccent: root.themeAccent
    }

    BatteryPopup {
        id: batteryPopup
        themeFg: root.themeFg
        themeBg: root.themeBg
        themeAccent: root.themeAccent
        powerProfile: topbar.powerProfile
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
