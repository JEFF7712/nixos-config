import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services" as Services

ShellRoot {
    id: root

    Services.AudioService {
        id: audioService
    }

    Services.MediaService {
        id: mediaService
        audioService: audioService
        detailedMonitoring: mediaPopup.shown
    }

    Services.CavaService {
        id: cavaService
        playing: mediaService.playing
        requested: topbar.cavaRequested || mediaPopup.active
    }

    Services.PowerService {
        id: powerService
        detailedMonitoring: batteryPopup.shown
    }

    Services.SystemService {
        id: systemService
        detailedMonitoring: systemPopup.shown
    }

    Services.NiriService {
        id: niriService
    }

    Services.NetworkService {
        id: networkService
        scanningRequested: wifiPopup.shown
    }

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
    property bool popupAttachToBar: false
    property string popupAnimationStyle: "softPop"
    property color dividerColor: "#1affffff"
    property color barBorderColor: "#3dffffff"
    property color barInnerHighlight: "#0fffffff"
    property color pillBg: "#0affffff"
    property color pillBorder: "#14ffffff"

    readonly property int popupTopMargin: barMarginTop + barHeight + (popupAttachToBar ? 0 : 10)

    // Profile theme JSON is sparse — omitted keys must fall back to these defaults
    // (same values as the property initializers), not the previous profile's values.
    function resetThemeDefaults() {
        root.themeFg = "#ffffff";
        root.themeBg = "#662a2a2a";
        root.popupBg = "#cc2a2a2a";
        root.themeRawBg = "#141414";
        root.themeAccent = "#ffffff";
        root.themeSecond = "#e8e8e8";
        root.themeWarm = "#e6dcc6";
        root.themeFresh = "#d6eadc";
        root.barRadius = 15;
        root.barHeight = 44;
        root.barMargin = 10;
        root.barMarginTop = 10;
        root.exclusiveZoneOffset = 0;
        root.showWorkspaces = true;
        root.showClock = true;
        root.showClockDate = true;
        root.showWorkspaceNumbers = true;
        root.showActiveWindow = false;
        root.showMedia = true;
        root.showVolume = true;
        root.showNetwork = true;
        root.showBluetooth = true;
        root.showBattery = true;
        root.showNotifications = true;
        root.showSystem = true;
        root.barFont = "JetBrainsMono Nerd Font";
        root.flatMode = false;
        root.showBarDividers = true;
        root.moduleAnimationStyle = "fade";
        // popupAttachToBar / popupAnimationStyle are applied at the end of
        // applyTheme only when they actually change — resetting them here would
        // flip false→true on every sharp wallpaper retheme and prewarm-flash
        // every InfoPopup (see InfoPopup.onPopupAttachToBarChanged).
        root.dividerColor = "#1affffff";
        root.barBorderColor = "#3dffffff";
        root.barInnerHighlight = "#0fffffff";
        root.pillBg = "#0affffff";
        root.pillBorder = "#14ffffff";
    }

    function applyTheme(theme) {
        const popups = [volumePopup, wifiPopup, bluetoothPopup, batteryPopup, calendarPopup, notificationsPopup, systemPopup, mediaPopup];
        for (const p of popups) {
            if (p)
                p.suppressPrewarm = true;
        }
        try {
            root.resetThemeDefaults();
            if (!theme)
                return;
            if (theme.fg)
                root.themeFg = theme.fg;
            if (theme.bg)
                root.themeBg = theme.bg;
            if (theme.popupBg)
                root.popupBg = theme.popupBg;
            if (theme.rawBg)
                root.themeRawBg = theme.rawBg;
            if (theme.accent)
                root.themeAccent = theme.accent;
            if (theme.second)
                root.themeSecond = theme.second;
            if (theme.warm)
                root.themeWarm = theme.warm;
            if (theme.fresh)
                root.themeFresh = theme.fresh;
            if (theme.barRadius !== undefined && theme.barRadius !== "")
                root.barRadius = parseInt(theme.barRadius);
            if (theme.barHeight !== undefined && theme.barHeight !== "")
                root.barHeight = parseInt(theme.barHeight);
            if (theme.barMargin !== undefined && theme.barMargin !== "") {
                root.barMargin = parseInt(theme.barMargin);
                // Themes often set barMargin alone (nord/sharp flush). Keep top
                // in sync unless they override barMarginTop explicitly — reset
                // breaks the QML binding of barMarginTop to barMargin.
                if (theme.barMarginTop === undefined)
                    root.barMarginTop = root.barMargin;
            }
            if (theme.barMarginTop !== undefined && theme.barMarginTop !== "")
                root.barMarginTop = parseInt(theme.barMarginTop);
            if (theme.exclusiveZoneOffset !== undefined)
                root.exclusiveZoneOffset = parseInt(theme.exclusiveZoneOffset);
            if (theme.showWorkspaces)
                root.showWorkspaces = theme.showWorkspaces === "true";
            if (theme.showClock)
                root.showClock = theme.showClock === "true";
            if (theme.showClockDate)
                root.showClockDate = theme.showClockDate === "true";
            if (theme.showWorkspaceNumbers)
                root.showWorkspaceNumbers = theme.showWorkspaceNumbers === "true";
            if (theme.showActiveWindow)
                root.showActiveWindow = theme.showActiveWindow === "true";
            if (theme.showMedia)
                root.showMedia = theme.showMedia === "true";
            if (theme.showVolume)
                root.showVolume = theme.showVolume === "true";
            if (theme.showNetwork)
                root.showNetwork = theme.showNetwork === "true";
            if (theme.showBluetooth)
                root.showBluetooth = theme.showBluetooth === "true";
            if (theme.showBattery)
                root.showBattery = theme.showBattery === "true";
            if (theme.showNotifications)
                root.showNotifications = theme.showNotifications === "true";
            if (theme.showSystem)
                root.showSystem = theme.showSystem === "true";
            if (theme.barFont)
                root.barFont = theme.barFont;
            if (theme.flatMode)
                root.flatMode = theme.flatMode === "true";
            if (theme.showBarDividers)
                root.showBarDividers = theme.showBarDividers === "true";
            if (theme.moduleAnimationStyle)
                root.moduleAnimationStyle = theme.moduleAnimationStyle;
            if (theme.dividerColor)
                root.dividerColor = theme.dividerColor;
            if (theme.barBorder)
                root.barBorderColor = theme.barBorder;
            if (theme.barInnerHighlight)
                root.barInnerHighlight = theme.barInnerHighlight;
            if (theme.pillBg)
                root.pillBg = theme.pillBg;
            if (theme.pillBorder)
                root.pillBorder = theme.pillBorder;

            // Only assign when the value changes so wallpaper rethemes (same sharp
            // layout, new colors) do not trip InfoPopup's attach/style prewarm flash.
            const nextAttach = theme.popupAttachToBar !== undefined ? theme.popupAttachToBar === "true" : false;
            const nextAnim = theme.popupAnimationStyle !== undefined ? theme.popupAnimationStyle : "softPop";
            if (root.popupAttachToBar !== nextAttach)
                root.popupAttachToBar = nextAttach;
            if (root.popupAnimationStyle !== nextAnim)
                root.popupAnimationStyle = nextAnim;
        } finally {
            for (const p of popups) {
                if (p)
                    p.suppressPrewarm = false;
            }
        }
    }

    property bool themeLoaded: false

    // Restart via Timer so running false→true is not coalesced in one frame.
    Timer {
        id: themeReloadTimer
        interval: 1
        repeat: false
        onTriggered: themeLoader.running = true
    }

    function reloadTheme() {
        themeLoader.running = false;
        themeReloadTimer.restart();
    }

    Process {
        id: themeLoader
        running: true
        command: ["select-quickshell-theme"]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = this.text.trim();
                if (!txt)
                    return;
                try {
                    root.applyTheme(JSON.parse(txt));
                    root.themeLoaded = true;
                } catch (e) {
                    console.warn("quickshell-theme.json parse failed:", e);
                }
            }
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/desktop-profiles/quickshell-theme-reload"
        watchChanges: true
        // watchChanges emits fileChanged on stamp bumps; onLoaded alone is not reliable.
        onFileChanged: if (root.themeLoaded)
            root.reloadTheme()
        onLoaded: if (root.themeLoaded)
            root.reloadTheme()
    }

    readonly property bool anyPopupShown: volumePopup.active || wifiPopup.active || bluetoothPopup.active || batteryPopup.active || calendarPopup.active || notificationsPopup.active || systemPopup.active || mediaPopup.active

    function showOnly(target) {
        const popups = [volumePopup, wifiPopup, bluetoothPopup, batteryPopup, calendarPopup, notificationsPopup, systemPopup, mediaPopup];
        for (const p of popups) {
            if (p !== target)
                p.close();
        }
        target.toggle();
    }

    function closeAll() {
        volumePopup.close();
        wifiPopup.close();
        bluetoothPopup.close();
        batteryPopup.close();
        calendarPopup.close();
        notificationsPopup.close();
        systemPopup.close();
        mediaPopup.close();
    }

    Topbar {
        id: topbar
        audioService: audioService
        mediaService: mediaService
        cavaService: cavaService
        powerService: powerService
        systemService: systemService
        niriService: niriService
        networkService: networkService
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
        barMarginTop: root.barMarginTop
        exclusiveZoneOffset: root.exclusiveZoneOffset
        showWorkspaces: root.showWorkspaces
        showClock: root.showClock
        showClockDate: root.showClockDate
        showWorkspaceNumbers: root.showWorkspaceNumbers
        showActiveWindow: root.showActiveWindow
        showMedia: root.showMedia
        showVolume: root.showVolume
        showNetwork: root.showNetwork
        showBluetooth: root.showBluetooth
        showBattery: root.showBattery
        showNotifications: root.showNotifications
        showSystem: root.showSystem
        barFont: root.barFont
        flatMode: root.flatMode
        showBarDividers: root.showBarDividers
        moduleAnimationStyle: root.moduleAnimationStyle
        dividerColor: root.dividerColor
        barBorderColor: root.barBorderColor
        barInnerHighlight: root.barInnerHighlight
        pillBg: root.pillBg
        pillBorder: root.pillBorder
        notificationCount: notificationsPopup.unreadCount
        onVolumeClicked: root.showOnly(volumePopup)
        onWifiClicked: root.showOnly(wifiPopup)
        onBluetoothClicked: root.showOnly(bluetoothPopup)
        onBatteryClicked: root.showOnly(batteryPopup)
        onClockClicked: root.showOnly(calendarPopup)
        onNotificationsClicked: root.showOnly(notificationsPopup)
        onSystemClicked: root.showOnly(systemPopup)
        onMediaClicked: root.showOnly(mediaPopup)
    }

    VolumePopup {
        id: volumePopup
        audioService: audioService
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        themeBorder: root.barBorderColor
        innerHighlight: root.barInnerHighlight
        dividerColor: root.dividerColor
        pillBg: root.pillBg
        pillBorder: root.pillBorder
        flatMode: root.flatMode
        popupAttachToBar: root.popupAttachToBar
        popupAnimationStyle: root.popupAnimationStyle
        topMargin: root.popupTopMargin
    }

    WifiPopup {
        id: wifiPopup
        networkService: networkService
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        themeBorder: root.barBorderColor
        innerHighlight: root.barInnerHighlight
        dividerColor: root.dividerColor
        pillBg: root.pillBg
        pillBorder: root.pillBorder
        flatMode: root.flatMode
        popupAttachToBar: root.popupAttachToBar
        popupAnimationStyle: root.popupAnimationStyle
        topMargin: root.popupTopMargin
    }

    BluetoothPopup {
        id: bluetoothPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        themeBorder: root.barBorderColor
        innerHighlight: root.barInnerHighlight
        dividerColor: root.dividerColor
        pillBg: root.pillBg
        pillBorder: root.pillBorder
        flatMode: root.flatMode
        popupAttachToBar: root.popupAttachToBar
        popupAnimationStyle: root.popupAnimationStyle
        topMargin: root.popupTopMargin
    }

    BatteryPopup {
        id: batteryPopup
        powerService: powerService
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        themeBorder: root.barBorderColor
        innerHighlight: root.barInnerHighlight
        dividerColor: root.dividerColor
        pillBg: root.pillBg
        pillBorder: root.pillBorder
        flatMode: root.flatMode
        popupAttachToBar: root.popupAttachToBar
        popupAnimationStyle: root.popupAnimationStyle
        topMargin: root.popupTopMargin
    }

    CalendarPopup {
        id: calendarPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        themeBorder: root.barBorderColor
        innerHighlight: root.barInnerHighlight
        dividerColor: root.dividerColor
        pillBg: root.pillBg
        pillBorder: root.pillBorder
        flatMode: root.flatMode
        popupAttachToBar: root.popupAttachToBar
        popupAnimationStyle: root.popupAnimationStyle
        topMargin: root.popupTopMargin
    }

    NotificationsPopup {
        id: notificationsPopup
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        themeWarm: root.themeWarm
        themeBorder: root.barBorderColor
        innerHighlight: root.barInnerHighlight
        dividerColor: root.dividerColor
        pillBg: root.pillBg
        pillBorder: root.pillBorder
        flatMode: root.flatMode
        popupAttachToBar: root.popupAttachToBar
        popupAnimationStyle: root.popupAnimationStyle
        topMargin: root.popupTopMargin
    }

    SystemPopup {
        id: systemPopup
        systemService: systemService
        niriService: niriService
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        themeWarm: root.themeWarm
        themeBorder: root.barBorderColor
        innerHighlight: root.barInnerHighlight
        dividerColor: root.dividerColor
        pillBg: root.pillBg
        pillBorder: root.pillBorder
        flatMode: root.flatMode
        popupAttachToBar: root.popupAttachToBar
        popupAnimationStyle: root.popupAnimationStyle
        topMargin: root.popupTopMargin
    }

    MediaPopup {
        id: mediaPopup
        mediaService: mediaService
        cavaService: cavaService
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        themeBorder: root.barBorderColor
        innerHighlight: root.barInnerHighlight
        dividerColor: root.dividerColor
        pillBg: root.pillBg
        pillBorder: root.pillBorder
        flatMode: root.flatMode
        popupAttachToBar: root.popupAttachToBar
        popupAnimationStyle: root.popupAnimationStyle
        topMargin: root.popupTopMargin
    }

    NotificationToasts {
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        themeWarm: root.themeWarm
        themeRawBg: root.themeRawBg
        themeBorder: root.barBorderColor
        innerHighlight: root.barInnerHighlight
        dividerColor: root.dividerColor
        flatMode: root.flatMode
        barFont: root.barFont
        topMargin: root.popupTopMargin
    }

    PanelWindow {
        id: catcher
        visible: root.anyPopupShown
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins {
            top: 64
        }
        exclusiveZone: -1
        color: "transparent"
        WlrLayershell.namespace: "quickshell-catcher"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeAll()
        }
    }
}
