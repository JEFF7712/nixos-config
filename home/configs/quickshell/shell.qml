//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "hass" as Hass
import "services" as Services

ShellRoot {
    id: root

    Services.AudioService {
        id: audioService
    }

    Services.BrightnessService {
        id: brightnessService
        detailedMonitoring: brightnessPopup.active
    }

    Services.MediaService {
        id: mediaService
        audioService: audioService
        detailedMonitoring: mediaPopup.active || mediaPopup.warming
    }

    Services.CavaService {
        id: cavaService
        playing: mediaService.playing
        requested: root.anyBarCavaRequested || mediaPopup.active || root.anyIdleGreetingShown
    }

    Services.PowerService {
        id: powerService
        detailedMonitoring: batteryPopup.active || batteryPopup.warming
    }

    Services.SystemService {
        id: systemService
        detailedMonitoring: systemPopup.active || systemPopup.warming || root.anyIdleGreetingShown
    }

    Services.NiriService {
        id: niriService
    }

    Services.NetworkService {
        id: networkService
        scanningRequested: wifiPopup.active || wifiPopup.warming
    }

    Services.BluetoothService {
        id: bluetoothService
        detailedMonitoring: bluetoothPopup.active || bluetoothPopup.warming
    }

    Hass.Service {
        id: hassService
    }

    Services.JsonPoller {
        id: agentPoller
        script: "agent-status"
        intervalMs: 4000
        active: root.anyIdleGreetingWaiting
    }

    Services.JsonPoller {
        id: homelabPoller
        script: "homelab-health"
        intervalMs: 60000
        active: root.anyIdleGreetingWaiting
    }

    Services.JsonPoller {
        id: calendarPoller
        script: "next-events"
        intervalMs: 300000
        active: root.anyIdleGreetingWaiting
    }

    property color themeFg: "#ffffff"
    property color themeBg: "#662a2a2a"
    property color popupBg: "#cc2a2a2a"
    property color themeRawBg: "#141414"
    property color themeAccent: "#ffffff"
    property color themeSecond: "#e8e8e8"
    property color themeWarm: "#e6dcc6"
    property color themeFresh: "#d6eadc"
    property var popupScreen: null
    readonly property Services.AudioService sharedAudioService: audioService
    readonly property Services.BrightnessService sharedBrightnessService: brightnessService
    readonly property Services.MediaService sharedMediaService: mediaService
    readonly property Services.CavaService sharedCavaService: cavaService
    readonly property Services.PowerService sharedPowerService: powerService
    readonly property Services.SystemService sharedSystemService: systemService
    readonly property Services.NiriService sharedNiriService: niriService
    readonly property Services.NetworkService sharedNetworkService: networkService
    readonly property Services.BluetoothService sharedBluetoothService: bluetoothService
    readonly property QtObject sharedHassService: hassService
    readonly property bool anyBarCavaRequested: {
        for (const bar of barVariants.instances) {
            if (bar.cavaRequested)
                return true;
        }
        return false;
    }

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
    property bool showBrightness: true
    property bool showNetwork: true
    property bool showBluetooth: true
    property bool showBattery: true
    property bool showNotifications: true
    property bool showSystem: true
    property bool showTray: true
    property bool showHass: true
    property string barFont: "JetBrainsMono Nerd Font"
    property bool flatMode: false
    property bool showBarDividers: true
    property string moduleAnimationStyle: "fade"
    property string motionStyle: "default"
    property bool showWorkspaceIndicator: true
    property bool showIdleGreeting: false
    property bool popupAttachToBar: false
    property string popupAnimationStyle: "softPop"
    property int osdMs: 120
    property color dividerColor: "#1affffff"
    property color barBorderColor: "#3dffffff"
    property color barInnerHighlight: "#0fffffff"
    property color pillBg: "#0affffff"
    property color pillBorder: "#14ffffff"

    readonly property int popupTopMargin: barMarginTop + barHeight + (popupAttachToBar ? 0 : 10)

    // Profile theme JSON is sparse — omitted keys must fall back to these defaults
    // (same values as the property initializers), not the previous profile's values.
    // Staged so a reload assigns each property once: resetting live properties first
    // flashed defaults (idle greeting off, white accent) for a frame on every retheme.
    function themeDefaults(): var {
        return {
            themeFg: "#ffffff",
            themeBg: "#662a2a2a",
            popupBg: "#cc2a2a2a",
            themeRawBg: "#141414",
            themeAccent: "#ffffff",
            themeSecond: "#e8e8e8",
            themeWarm: "#e6dcc6",
            themeFresh: "#d6eadc",
            barRadius: 15,
            barHeight: 44,
            barMargin: 10,
            barMarginTop: 10,
            exclusiveZoneOffset: 0,
            showWorkspaces: true,
            showClock: true,
            showClockDate: true,
            showWorkspaceNumbers: true,
            showActiveWindow: false,
            showMedia: true,
            showVolume: true,
            showBrightness: true,
            showNetwork: true,
            showBluetooth: true,
            showBattery: true,
            showNotifications: true,
            showSystem: true,
            showTray: true,
            showHass: true,
            barFont: "JetBrainsMono Nerd Font",
            flatMode: false,
            showBarDividers: true,
            moduleAnimationStyle: "fade",
            motionStyle: "default",
            showWorkspaceIndicator: true,
            showIdleGreeting: false,
            osdMs: 120,
            dividerColor: "#1affffff",
            barBorderColor: "#3dffffff",
            barInnerHighlight: "#0fffffff",
            pillBg: "#0affffff",
            pillBorder: "#14ffffff"
        };
    }

    function applyTheme(theme) {
        const popups = [volumePopup, brightnessPopup, wifiPopup, bluetoothPopup, batteryPopup, calendarPopup, notificationsPopup, systemPopup, mediaPopup, hassPopup];
        for (const p of popups) {
            if (p)
                p.suppressPrewarm = true;
        }
        let attachOrAnimChanged = false;
        try {
            const next = root.themeDefaults();
            if (theme) {
                if (theme.fg)
                    next.themeFg = theme.fg;
                if (theme.bg)
                    next.themeBg = theme.bg;
                if (theme.popupBg)
                    next.popupBg = theme.popupBg;
                if (theme.rawBg)
                    next.themeRawBg = theme.rawBg;
                if (theme.accent)
                    next.themeAccent = theme.accent;
                if (theme.second)
                    next.themeSecond = theme.second;
                if (theme.warm)
                    next.themeWarm = theme.warm;
                if (theme.fresh)
                    next.themeFresh = theme.fresh;
                if (theme.barRadius !== undefined && theme.barRadius !== "")
                    next.barRadius = parseInt(theme.barRadius);
                if (theme.barHeight !== undefined && theme.barHeight !== "")
                    next.barHeight = parseInt(theme.barHeight);
                if (theme.barMargin !== undefined && theme.barMargin !== "") {
                    next.barMargin = parseInt(theme.barMargin);
                    // Themes often set barMargin alone; keep top in sync unless overridden.
                    if (theme.barMarginTop === undefined)
                        next.barMarginTop = next.barMargin;
                }
                if (theme.barMarginTop !== undefined && theme.barMarginTop !== "")
                    next.barMarginTop = parseInt(theme.barMarginTop);
                if (theme.exclusiveZoneOffset !== undefined)
                    next.exclusiveZoneOffset = parseInt(theme.exclusiveZoneOffset);
                if (theme.showWorkspaces)
                    next.showWorkspaces = theme.showWorkspaces === "true";
                if (theme.showClock)
                    next.showClock = theme.showClock === "true";
                if (theme.showClockDate)
                    next.showClockDate = theme.showClockDate === "true";
                if (theme.showWorkspaceNumbers)
                    next.showWorkspaceNumbers = theme.showWorkspaceNumbers === "true";
                if (theme.showActiveWindow)
                    next.showActiveWindow = theme.showActiveWindow === "true";
                if (theme.showMedia)
                    next.showMedia = theme.showMedia === "true";
                if (theme.showVolume)
                    next.showVolume = theme.showVolume === "true";
                if (theme.showBrightness)
                    next.showBrightness = theme.showBrightness === "true";
                if (theme.showNetwork)
                    next.showNetwork = theme.showNetwork === "true";
                if (theme.showBluetooth)
                    next.showBluetooth = theme.showBluetooth === "true";
                if (theme.showBattery)
                    next.showBattery = theme.showBattery === "true";
                if (theme.showNotifications)
                    next.showNotifications = theme.showNotifications === "true";
                if (theme.showSystem)
                    next.showSystem = theme.showSystem === "true";
                if (theme.showTray)
                    next.showTray = theme.showTray === "true";
                if (theme.showHass)
                    next.showHass = theme.showHass === "true";
                if (theme.barFont)
                    next.barFont = theme.barFont;
                if (theme.flatMode)
                    next.flatMode = theme.flatMode === "true";
                if (theme.showBarDividers)
                    next.showBarDividers = theme.showBarDividers === "true";
                if (theme.moduleAnimationStyle)
                    next.moduleAnimationStyle = theme.moduleAnimationStyle;
                if (theme.motionStyle)
                    next.motionStyle = theme.motionStyle;
                if (theme.showWorkspaceIndicator)
                    next.showWorkspaceIndicator = theme.showWorkspaceIndicator === "true";
                if (theme.showIdleGreeting)
                    next.showIdleGreeting = theme.showIdleGreeting === "true";
                if (theme.osdMs !== undefined && theme.osdMs !== "")
                    next.osdMs = parseInt(theme.osdMs);
                if (theme.dividerColor)
                    next.dividerColor = theme.dividerColor;
                if (theme.barBorder)
                    next.barBorderColor = theme.barBorder;
                if (theme.barInnerHighlight)
                    next.barInnerHighlight = theme.barInnerHighlight;
                if (theme.pillBg)
                    next.pillBg = theme.pillBg;
                if (theme.pillBorder)
                    next.pillBorder = theme.pillBorder;
            }
            for (const key in next) {
                const value = next[key];
                const isColor = typeof value === "string" && value.startsWith("#");
                if (isColor ? !Qt.colorEqual(root[key], value) : root[key] !== value)
                    root[key] = value;
            }
            if (!theme)
                return;

            // Only assign when the value changes so wallpaper rethemes (same sharp
            // layout, new colors) do not trip InfoPopup's attach/style prewarm flash.
            const nextAttach = theme.popupAttachToBar !== undefined ? theme.popupAttachToBar === "true" : false;
            const nextAnim = theme.popupAnimationStyle !== undefined ? theme.popupAnimationStyle : "softPop";
            if (root.popupAttachToBar !== nextAttach) {
                root.popupAttachToBar = nextAttach;
                attachOrAnimChanged = true;
            }
            if (root.popupAnimationStyle !== nextAnim) {
                root.popupAnimationStyle = nextAnim;
                attachOrAnimChanged = true;
            }
        } finally {
            for (const p of popups) {
                if (p)
                    p.suppressPrewarm = false;
            }
            root.themeRevision++;
            // Change handlers ran while suppressed; retry now that poseLocked snaps
            // off-screen without animating (no bar flash on profile switch).
            if (attachOrAnimChanged) {
                for (const p of popups) {
                    if (p)
                        p.prewarm();
                }
            }
        }
    }

    property bool themeLoaded: false
    // Bumped after every applied theme; the idle greeting waits on it during wallpaper changes.
    property int themeRevision: 0

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
        // Absolute path: quickshell's PATH may omit ~/.local/bin on some spawns.
        command: [Quickshell.env("HOME") + "/.local/bin/select-quickshell-theme"]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = this.text.trim();
                if (txt) {
                    try {
                        root.applyTheme(JSON.parse(txt));
                    } catch (e) {
                        console.warn("quickshell-theme.json parse failed:", e);
                    }
                }
                // Reveal even on empty/parse failure so the bar is never stuck hidden.
                root.themeLoaded = true;
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

    readonly property bool anyPopupShown: volumePopup.active || brightnessPopup.active || wifiPopup.active || bluetoothPopup.active || batteryPopup.active || calendarPopup.active || notificationsPopup.active || systemPopup.active || mediaPopup.active || hassPopup.active
    readonly property bool anyPopupWarming: volumePopup.warming || brightnessPopup.warming || wifiPopup.warming || bluetoothPopup.warming || batteryPopup.warming || calendarPopup.warming || notificationsPopup.warming || systemPopup.warming || mediaPopup.warming || hassPopup.warming

    function showOnly(target, centerX, screen) {
        root.popupScreen = screen;
        target.anchorCenterX = (centerX === undefined || centerX === null) ? -1 : centerX;
        const popups = [volumePopup, brightnessPopup, wifiPopup, bluetoothPopup, batteryPopup, calendarPopup, notificationsPopup, systemPopup, mediaPopup, hassPopup];
        for (const p of popups) {
            if (p !== target)
                p.close();
        }
        target.toggle();
    }

    function prewarmOn(target, screen) {
        root.popupScreen = screen;
        target.prewarm();
    }

    function closeAll() {
        volumePopup.close();
        brightnessPopup.close();
        wifiPopup.close();
        bluetoothPopup.close();
        batteryPopup.close();
        calendarPopup.close();
        notificationsPopup.close();
        systemPopup.close();
        mediaPopup.close();
        hassPopup.close();
    }

    Variants {
        id: barVariants
        model: Quickshell.screens

        Topbar {
            id: topbar
            property var modelData
            screen: modelData
            audioService: root.sharedAudioService
            brightnessService: root.sharedBrightnessService
            mediaService: root.sharedMediaService
            cavaService: root.sharedCavaService
            powerService: root.sharedPowerService
            systemService: root.sharedSystemService
            niriService: root.sharedNiriService
            networkService: root.sharedNetworkService
            bluetoothService: root.sharedBluetoothService
            hassService: root.sharedHassService
            themeReady: root.themeLoaded
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
            showBrightness: root.showBrightness
            showNetwork: root.showNetwork
            showBluetooth: root.showBluetooth
            showBattery: root.showBattery
            showNotifications: root.showNotifications
            showSystem: root.showSystem
            showTray: root.showTray
            showHass: root.showHass
            barFont: root.barFont
            flatMode: root.flatMode
            showBarDividers: root.showBarDividers
            moduleAnimationStyle: root.moduleAnimationStyle
            motionStyle: root.motionStyle
            showWorkspaceIndicator: root.showWorkspaceIndicator
            dividerColor: root.dividerColor
            barBorderColor: root.barBorderColor
            barInnerHighlight: root.barInnerHighlight
            pillBg: root.pillBg
            pillBorder: root.pillBorder
            notificationCount: NotifService.count
            focusActive: NotifService.dnd
            onFocusToggleRequested: NotifService.toggleFocus()
            onVolumeClicked: centerX => root.showOnly(volumePopup, centerX, modelData)
            onBrightnessClicked: centerX => root.showOnly(brightnessPopup, centerX, modelData)
            onWifiClicked: centerX => root.showOnly(wifiPopup, centerX, modelData)
            onBluetoothClicked: centerX => root.showOnly(bluetoothPopup, centerX, modelData)
            onBatteryClicked: centerX => root.showOnly(batteryPopup, centerX, modelData)
            onClockClicked: centerX => root.showOnly(calendarPopup, centerX, modelData)
            onNotificationsClicked: centerX => root.showOnly(notificationsPopup, centerX, modelData)
            onSystemClicked: centerX => root.showOnly(systemPopup, centerX, modelData)
            onMediaClicked: centerX => root.showOnly(mediaPopup, centerX, modelData)
            onHassClicked: centerX => root.showOnly(hassPopup, centerX, modelData)
            onVolumeHovered: root.prewarmOn(volumePopup, modelData)
            onBrightnessHovered: root.prewarmOn(brightnessPopup, modelData)
            onWifiHovered: root.prewarmOn(wifiPopup, modelData)
            onBluetoothHovered: root.prewarmOn(bluetoothPopup, modelData)
            onBatteryHovered: root.prewarmOn(batteryPopup, modelData)
            onClockHovered: root.prewarmOn(calendarPopup, modelData)
            onNotificationsHovered: root.prewarmOn(notificationsPopup, modelData)
            onSystemHovered: root.prewarmOn(systemPopup, modelData)
            onMediaHovered: root.prewarmOn(mediaPopup, modelData)
            onHassHovered: root.prewarmOn(hassPopup, modelData)
        }
    }

    // Workspace already empty: fetch before the greeting reveals so its height is settled.
    readonly property bool anyIdleGreetingWaiting: {
        for (const g of greetingVariants.instances) {
            if (g.enabled && g.workspaceEmpty)
                return true;
        }
        return false;
    }

    readonly property bool anyIdleGreetingShown: {
        for (const g of greetingVariants.instances) {
            if (g.revealed)
                return true;
        }
        return false;
    }

    Variants {
        id: greetingVariants
        model: Quickshell.screens

        IdleGreeting {
            property var modelData
            screen: modelData
            niriService: root.sharedNiriService
            systemService: root.sharedSystemService
            mediaService: root.sharedMediaService
            cavaService: root.sharedCavaService
            bluetoothService: root.sharedBluetoothService
            powerService: root.sharedPowerService
            agentFeed: agentPoller
            homelabFeed: homelabPoller
            calendarFeed: calendarPoller
            themeReady: root.themeLoaded
            themeRevision: root.themeRevision
            enabled: root.showIdleGreeting
            themeFg: root.themeFg
            themeSecond: root.themeSecond
            themeAccent: root.themeAccent
            barFont: root.barFont
        }
    }

    VolumePopup {
        id: volumePopup
        screen: root.popupScreen
        audioService: audioService
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        themeWarm: root.themeWarm
        themeFresh: root.themeFresh
        themeBorder: root.barBorderColor
        innerHighlight: root.barInnerHighlight
        dividerColor: root.dividerColor
        pillBg: root.pillBg
        pillBorder: root.pillBorder
        flatMode: root.flatMode
        popupAttachToBar: root.popupAttachToBar
        popupAnimationStyle: root.popupAnimationStyle
        barFont: root.barFont
        topMargin: root.popupTopMargin
        barMargin: root.barMargin
    }

    BrightnessPopup {
        id: brightnessPopup
        screen: root.popupScreen
        brightnessService: brightnessService
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
        barFont: root.barFont
        topMargin: root.popupTopMargin
        barMargin: root.barMargin
    }

    WifiPopup {
        id: wifiPopup
        screen: root.popupScreen
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
        barFont: root.barFont
        topMargin: root.popupTopMargin
        barMargin: root.barMargin
    }

    BluetoothPopup {
        id: bluetoothPopup
        screen: root.popupScreen
        bluetoothService: bluetoothService
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
        barFont: root.barFont
        topMargin: root.popupTopMargin
        barMargin: root.barMargin
    }

    BatteryPopup {
        id: batteryPopup
        screen: root.popupScreen
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
        barFont: root.barFont
        topMargin: root.popupTopMargin
        barMargin: root.barMargin
    }

    CalendarPopup {
        id: calendarPopup
        screen: root.popupScreen
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
        barFont: root.barFont
        topMargin: root.popupTopMargin
        barMargin: root.barMargin
    }

    NotificationsPopup {
        id: notificationsPopup
        screen: root.popupScreen
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
        barFont: root.barFont
        topMargin: root.popupTopMargin
        barMargin: root.barMargin
    }

    SystemPopup {
        id: systemPopup
        screen: root.popupScreen
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
        barFont: root.barFont
        topMargin: root.popupTopMargin
        barMargin: root.barMargin
    }

    MediaPopup {
        id: mediaPopup
        screen: root.popupScreen
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
        barFont: root.barFont
        topMargin: root.popupTopMargin
        barMargin: root.barMargin
    }

    HassPopup {
        id: hassPopup
        screen: root.popupScreen
        hassService: hassService
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        themeSecond: root.themeSecond
        themeRawBg: root.themeRawBg
        themeBorder: root.barBorderColor
        innerHighlight: root.barInnerHighlight
        dividerColor: root.dividerColor
        pillBg: root.pillBg
        pillBorder: root.pillBorder
        flatMode: root.flatMode
        popupAttachToBar: root.popupAttachToBar
        popupAnimationStyle: root.popupAnimationStyle
        barFont: root.barFont
        topMargin: root.popupTopMargin
        barMargin: root.barMargin
    }

    property bool osdSettled: false

    Timer {
        id: osdSettleTimer
        interval: 1200
        running: true
        repeat: false
        onTriggered: root.osdSettled = true
    }

    OsdOverlay {
        id: osdOverlay
        screen: root.popupScreen ? root.popupScreen : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        themeWarm: root.themeWarm
        themeBorder: root.barBorderColor
        innerHighlight: root.barInnerHighlight
        pillBg: root.pillBg
        flatMode: root.flatMode
        barRadius: root.barRadius
        barFont: root.barFont
        osdMs: root.osdMs
    }

    IpcHandler {
        target: "osd"

        function showVolume(label: string, percent: int, muted: bool): string {
            osdOverlay.showVolume(label, percent, muted, true);
            return "ok";
        }

        function showMic(label: string, percent: int, muted: bool): string {
            osdOverlay.showMic(label, percent, muted, true);
            return "ok";
        }

        function showBrightness(label: string, percent: int): string {
            osdOverlay.showBrightness(label, percent, true);
            return "ok";
        }

        function showStatus(glyph: string, label: string, badge: string): string {
            osdOverlay.showStatus(glyph, label, badge);
            return "ok";
        }
    }

    Connections {
        target: audioService

        function onVolumePercentChanged() {
            if (!root.osdSettled || volumePopup.active || mediaPopup.active || osdOverlay.ipcHandledRecently())
                return;
            osdOverlay.showVolume(audioService.activeOutputLabel || "Output", audioService.volumePercent, audioService.muted, false);
        }

        function onMutedChanged() {
            if (!root.osdSettled || volumePopup.active || mediaPopup.active || osdOverlay.ipcHandledRecently())
                return;
            osdOverlay.showVolume(audioService.activeOutputLabel || "Output", audioService.volumePercent, audioService.muted, false);
        }

        function onSourceMutedChanged() {
            if (!root.osdSettled || volumePopup.active || osdOverlay.ipcHandledRecently())
                return;
            osdOverlay.showMic(audioService.activeInputLabel || "Microphone", audioService.sourceVolumePercent, audioService.sourceMuted, false);
        }
    }

    Connections {
        target: brightnessService

        function onAveragePercentChanged() {
            if (!root.osdSettled || brightnessPopup.active || osdOverlay.ipcHandledRecently())
                return;
            osdOverlay.showBrightness("Display", brightnessService.averagePercent, false);
        }
    }

    Connections {
        target: NotifService

        function onDndChanged() {
            if (!root.osdSettled || notificationsPopup.active)
                return;
            osdOverlay.showStatus(NotifService.dnd ? "󰂛" : "󰂚", "Focus mode", NotifService.dnd ? "on" : "off");
        }
    }

    Connections {
        target: powerService

        function onIdleInhibitedChanged() {
            if (!root.osdSettled || batteryPopup.active)
                return;
            osdOverlay.showStatus("󰅶", "Stay awake", powerService.idleInhibited ? "on" : "off");
        }
    }

    NotificationToasts {
        themeFg: root.themeFg
        themeBg: root.popupBg
        themeAccent: root.themeAccent
        themeSecond: root.themeSecond
        themeWarm: root.themeWarm
        themeBorder: root.barBorderColor
        innerHighlight: root.barInnerHighlight
        pillBg: root.pillBg
        pillBorder: root.pillBorder
        flatMode: root.flatMode
        popupAttachToBar: root.popupAttachToBar
        popupAnimationStyle: root.popupAnimationStyle
        barFont: root.barFont
        barRadius: root.barRadius
        topMargin: root.popupTopMargin
        barMargin: root.barMargin
    }

    QtObject {
        id: batteryAlerts
        property string level: ""

        function evaluate(): void {
            if (!powerService.available || powerService.state !== "discharging") {
                level = "";
                return;
            }
            const pct = powerService.chargePercent;
            if (pct <= 10 && level !== "critical") {
                level = "critical";
                Quickshell.execDetached(["notify-send", "-u", "critical", "Battery critical", pct + "% remaining"]);
            } else if (pct <= 20 && level !== "warning" && level !== "critical") {
                level = "warning";
                Quickshell.execDetached(["notify-send", "-u", "normal", "Battery low", pct + "% remaining"]);
            } else if (pct > 20) {
                level = "";
            }
        }
    }

    Connections {
        target: powerService
        function onAvailableChanged(): void {
            batteryAlerts.evaluate();
        }
        function onStateChanged(): void {
            batteryAlerts.evaluate();
        }
        function onChargePercentChanged(): void {
            batteryAlerts.evaluate();
        }
    }

    property bool switcherShown: false
    property var switcherProfiles: []
    property string switcherActiveProfile: ""
    property int switcherFocusedIndex: -1

    function openProfileSwitcher(): void {
        root.closeAll();
        switcherListProc.running = true;
        switcherActiveProc.running = true;
        root.switcherShown = true;
    }

    function closeProfileSwitcher(): void {
        root.switcherShown = false;
        root.switcherFocusedIndex = -1;
    }

    function toggleProfileSwitcher(): void {
        if (root.switcherShown)
            root.closeProfileSwitcher();
        else
            root.openProfileSwitcher();
    }

    function activateProfile(name: string): void {
        // Detach with setsid -f and redirect all stdio so the child survives
        // if quickshell-bar restarts and can't be killed by SIGPIPE.
        switcherExecProc.command = ["bash", "-c", "setsid -f switch-profile \"$1\" </dev/null >/dev/null 2>&1", "--", name];
        switcherExecProc.running = true;
        root.closeProfileSwitcher();
    }

    IpcHandler {
        target: "profile"
        function toggle(): void {
            root.toggleProfileSwitcher();
        }
        function show(): void {
            root.openProfileSwitcher();
        }
        function hide(): void {
            root.closeProfileSwitcher();
        }
    }

    Process {
        id: switcherListProc
        command: ["sh", "-c", "for d in \"$HOME\"/.config/desktop-profiles/*/; do [ -d \"$d\" ] && basename \"$d\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.switcherProfiles = text.split("\n").map(s => s.trim()).filter(s => s.length > 0);
            }
        }
    }

    Process {
        id: switcherActiveProc
        command: ["sh", "-c", "cat \"$HOME\"/.config/desktop-profiles/active 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.switcherActiveProfile = text.trim();
            }
        }
    }

    Process {
        id: switcherExecProc
        command: ["true"]
    }

    Variants {
        model: Quickshell.screens

        ProfileSwitcher {
            property var modelData
            screen: modelData
            shown: root.switcherShown
            profiles: root.switcherProfiles
            activeProfile: root.switcherActiveProfile
            focusedIndex: root.switcherFocusedIndex
            onCloseRequested: root.closeProfileSwitcher()
            onFocusRequested: index => {
                root.switcherFocusedIndex = index;
            }
            onActivateRequested: name => {
                root.activateProfile(name);
            }
        }
    }

    PanelWindow {
        id: catcher
        screen: root.popupScreen
        // Warm a tiny surface on hover/prewarm; expand only while a popup is interactive
        // so we do not cover the desktop (or steal clicks) during idle warm.
        readonly property bool interactive: root.anyPopupShown
        visible: catcher.interactive || root.anyPopupWarming
        anchors {
            top: true
            bottom: catcher.interactive
            left: true
            right: catcher.interactive
        }
        margins {
            top: 64
        }
        implicitWidth: catcher.interactive ? 0 : 1
        implicitHeight: catcher.interactive ? 0 : 1
        exclusiveZone: -1
        color: "transparent"
        WlrLayershell.namespace: "quickshell-catcher"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            enabled: catcher.interactive
            onClicked: root.closeAll()
        }
    }
}
