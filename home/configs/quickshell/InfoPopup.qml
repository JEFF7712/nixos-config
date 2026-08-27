import QtQuick
import Quickshell
import Quickshell.Wayland
import "PopupAnchor.js" as PopupAnchor

PanelWindow {
    id: root

    property bool shown: false
    property string title: ""
    property string popupPosition: "right"
    property int topMargin: 64
    // When attached to a flat flush bar, match the bar's side inset (usually 0)
    // so the popup hangs from the screen edge instead of floating 10px inboard.
    property int barMargin: 0
    property color themeFg: "#ffffff"
    property color themeBg: "#662a2a2a"
    property color themeAccent: "#ffffff"
    property color themeRawBg: "#141414"
    property color themeBorder: Qt.rgba(1, 1, 1, 0.24)
    property color innerHighlight: Qt.rgba(1, 1, 1, 0.06)
    property color dividerColor: Qt.rgba(1, 1, 1, 0.1)
    property color pillBg: Qt.rgba(1, 1, 1, 0.05)
    property color pillBorder: Qt.rgba(1, 1, 1, 0.1)
    property bool flatMode: false
    property bool popupAttachToBar: false
    property bool edgeSlide: false
    property string popupAnimationStyle: "softPop"
    property real anchorCenterX: -1
    property int frozenLeft: -1
    property bool warming: false
    property bool opening: false
    property bool closing: false
    // Must not key off `shown`: openTimer used to clear settle in the same tick.
    property bool poseLocked: false
    // Bumped when locking pose so card bindings re-evaluate and snap (a disabled
    // Behavior mid-animation otherwise leaves x/y/opacity/scale stuck mid-tween).
    property int poseEpoch: 0
    // Gate prewarm during startup theme-load (attach/style changes would flash).
    property bool ready: false
    // Set by shell.applyTheme while swapping profile/wallpaper themes so
    // attach/style changes do not prewarm-map every popup.
    property bool suppressPrewarm: false
    property int frozenHeight: 0
    readonly property string effectiveAnimationStyle: popupAttachToBar ? "attachedSlide" : popupAnimationStyle
    readonly property bool attachedSlide: effectiveAnimationStyle === "attachedSlide"
    readonly property bool quickFade: effectiveAnimationStyle === "quickFade"
    readonly property bool floatSlide: effectiveAnimationStyle === "floatSlide"
    readonly property bool unfold: effectiveAnimationStyle === "unfold"
    readonly property bool sideSlide: attachedSlide && edgeSlide
    readonly property bool active: shown || opening || closing
    // niri blur follows the layer-shell rect, not QML opacity — unmap with the chrome.
    readonly property bool mapped: shown || opening || warming || closing
    readonly property int cardRadius: flatMode ? 0 : 15
    readonly property int sideMargin: popupAttachToBar ? barMargin : 10
    readonly property int contentHeight: outerColumn.implicitHeight + 28
    // Prefer frozen height while mapping so hiddenY is not -1 from collapsed implicitHeight.
    readonly property int slideHideHeight: Math.max(1, frozenHeight > 0 ? frozenHeight : contentHeight)
    readonly property int hiddenX: sideSlide ? (popupPosition === "left" ? -card.width : card.width) : 0
    readonly property int hiddenY: sideSlide ? 0 : attachedSlide ? -slideHideHeight : floatSlide ? -10 : unfold ? -24 : quickFade ? -2 : -4
    readonly property real hiddenOpacity: attachedSlide ? 1.0 : floatSlide ? 0.72 : quickFade ? 0.0 : 0.0
    readonly property real hiddenScale: attachedSlide ? 1.0 : quickFade ? 0.985 : unfold ? 0.98 : 0.96
    readonly property int motionDuration: quickFade ? 190 : unfold ? 220 : 180
    readonly property bool moduleAnchored: !popupAttachToBar && anchorCenterX >= 0 && frozenLeft >= 0
    readonly property int warmPulseMs: 200
    readonly property int keepWarmMs: 1500

    function freezeAnchor() {
        const outW = screen ? screen.width : 0;
        root.frozenLeft = PopupAnchor.clampedLeft(root.anchorCenterX, root.implicitWidth, outW, root.barMargin);
    }

    function lockPose() {
        // Lock before any frozenHeight / shown mutation so Behaviors cannot start.
        root.poseLocked = true;
        root.poseEpoch++;
    }

    function clearWarm() {
        // Stay pose-locked while idle: unlocking here lets hiddenY retarget with
        // Behaviors on, so a quick re-hover can map mid-tween and flash chrome.
        root.lockPose();
        root.warming = false;
        if (!root.active)
            root.frozenHeight = 0;
        warmTimer.interval = root.warmPulseMs;
    }

    function enterKeepWarm() {
        // 1px keep-warm: surface stays hot for reopen without a full-size blur ghost.
        root.closing = false;
        root.lockPose();
        root.frozenHeight = 1;
        root.warming = true;
        warmTimer.interval = root.keepWarmMs;
        warmTimer.restart();
    }

    default property alias body: contentColumn.data
    property alias background: bgContainer.data

    function prewarm() {
        if (root.suppressPrewarm || !root.ready || root.active)
            return;
        // Always 1px: layershell remap is what we need. Full-height attached warm
        // flashed the chrome whenever clip/pose was a frame behind (sharp profile).
        root.lockPose();
        root.frozenHeight = 1;
        root.warming = true;
        warmTimer.interval = root.warmPulseMs;
        warmTimer.restart();
    }

    onSuppressPrewarmChanged: {
        if (!root.suppressPrewarm)
            return;
        warmTimer.stop();
        root.lockPose();
        root.warming = false;
        root.closing = false;
        if (!root.active)
            root.frozenHeight = 0;
        warmTimer.interval = root.warmPulseMs;
    }

    function open() {
        root.ready = true;
        openTimer.stop();
        showTimer.stop();
        warmTimer.stop();
        root.closing = false;
        if (!root.attachedSlide)
            root.freezeAnchor();
        // Two-tick settle for every style: unlock Behaviors, then flip shown.
        // Same-tick unlock+show can still snap (Behavior enable races the pose bind).
        root.lockPose();
        root.warming = false;
        root.frozenHeight = Math.max(1, root.contentHeight);
        root.opening = true;
        root.shown = false;
        openTimer.restart();
    }

    function close() {
        openTimer.stop();
        showTimer.stop();
        warmTimer.stop();

        if (!root.shown && !root.opening) {
            root.closing = false;
            root.clearWarm();
            return;
        }

        // Instant unmap. Niri blur follows the layershell rect, not the card —
        // an animated close leaves an empty blur field after the chrome is gone.
        root.lockPose();
        root.opening = false;
        root.closing = false;
        root.shown = false;
        root.enterKeepWarm();
    }

    onPopupAttachToBarChanged: root.prewarm()
    onPopupAnimationStyleChanged: root.prewarm()
    function toggle() {
        if (root.shown || root.opening)
            root.close();
        else
            root.open();
    }

    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: mapped && root.ready
    anchors {
        top: true
        right: root.moduleAnchored ? false : root.popupPosition === "right"
        left: root.moduleAnchored ? true : root.popupPosition === "left"
    }
    margins {
        top: root.topMargin
        right: root.moduleAnchored ? 0 : (root.popupPosition === "right" ? root.sideMargin : 0)
        left: root.moduleAnchored ? root.frozenLeft : (root.popupPosition === "left" ? root.sideMargin : 0)
    }
    implicitWidth: 300
    implicitHeight: {
        // If unmap lags, a full-size transparent buffer still gets niri blur.
        if (root.warming || root.opening || root.closing)
            return Math.max(1, root.frozenHeight);
        if (!root.shown)
            return 1;
        return root.contentHeight;
    }
    exclusiveZone: -1
    color: "transparent"

    Timer {
        id: readyTimer
        interval: 700
        running: true
        repeat: false
        onTriggered: {
            root.ready = true;
            // Map once now so the first click does not pay layershell creation mid-animation.
            root.prewarm();
        }
    }

    Timer {
        id: warmTimer
        interval: root.warmPulseMs
        repeat: false
        onTriggered: root.clearWarm()
    }

    // Two ticks: unlock Behaviors, then flip shown so the open animation runs.
    // Same-tick unlock+show can still snap (Behavior enable races the pose bind).
    Timer {
        id: openTimer
        interval: 16
        repeat: false
        onTriggered: {
            root.poseLocked = false;
            showTimer.restart();
        }
    }

    Timer {
        id: showTimer
        interval: 16
        repeat: false
        onTriggered: {
            root.shown = true;
            root.opening = false;
            root.frozenHeight = 0;
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    Item {
        anchors.fill: parent
        clip: root.attachedSlide || root.unfold

        Rectangle {
            id: card
            width: parent.width
            height: parent.height
            radius: root.cardRadius
            color: root.themeBg
            border.width: 1
            border.color: root.themeBorder
            // poseEpoch forces a rebind snap when lockPose() runs mid-Behavior.
            x: {
                root.poseEpoch;
                return root.shown ? 0 : root.hiddenX;
            }
            y: {
                root.poseEpoch;
                return root.shown ? 0 : root.hiddenY;
            }
            // Warm must stay invisible even if pose/clip races (attachedSlide is opacity 1).
            opacity: {
                root.poseEpoch;
                if (root.warming)
                    return 0.0;
                return root.shown ? 1.0 : root.hiddenOpacity;
            }
            scale: {
                root.poseEpoch;
                return root.shown ? 1.0 : root.hiddenScale;
            }
            transformOrigin: root.attachedSlide ? (root.popupPosition === "left" ? Item.TopLeft : Item.TopRight) : Item.Top
            Behavior on x {
                enabled: !root.poseLocked
                NumberAnimation {
                    duration: root.motionDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: !root.poseLocked
                NumberAnimation {
                    duration: root.motionDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                enabled: !root.poseLocked
                NumberAnimation {
                    duration: root.motionDuration
                    easing.type: root.quickFade ? Easing.OutCubic : Easing.InOutCubic
                }
            }
            Behavior on scale {
                enabled: !root.attachedSlide && !root.poseLocked
                NumberAnimation {
                    duration: root.motionDuration
                    easing.type: Easing.InOutCubic
                }
            }

            Item {
                id: bgContainer
                anchors.fill: parent
                anchors.margins: 1
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                color: root.innerHighlight
            }

            Column {
                id: outerColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6

                Text {
                    text: root.title
                    color: root.themeAccent
                    opacity: 0.7
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 9
                        letterSpacing: 1.6
                        weight: Font.Medium
                    }
                }

                Rectangle {
                    width: outerColumn.width
                    height: 1
                    color: root.dividerColor
                }

                Column {
                    id: contentColumn
                    width: outerColumn.width
                    spacing: 4
                }
            }
        }
    }
}
