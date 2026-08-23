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
    // Snap x/y/opacity/scale without Behavior. Must not key off `shown` —
    // openTimer used to clear settle via shown=true in the same tick as the
    // pose change, and Qt applied the final value while Behavior was still
    // disabled (instant open).
    property bool poseLocked: false
    // False until the shell has settled after launch. The startup theme-load
    // flips popupAttachToBar/popupAnimationStyle, whose change handlers call
    // prewarm(); without this gate every popup would briefly map (warming ->
    // visible) and flash near the bar on every profile switch.
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
    // niri background-effect blur follows the layer-shell rectangle, not QML
    // opacity. Holding this surface mapped while the card fades to 0 leaves an
    // empty rounded blur square after the popup chrome is gone. Unmap as soon
    // as shown/opening/warming are false — close animation cannot move compositor blur.
    readonly property bool mapped: shown || opening || warming
    readonly property int cardRadius: flatMode ? 0 : 15
    readonly property int sideMargin: popupAttachToBar ? barMargin : 10
    readonly property int contentHeight: outerColumn.implicitHeight + 28
    readonly property int hiddenX: sideSlide ? (popupPosition === "left" ? -card.width : card.width) : 0
    readonly property int hiddenY: sideSlide ? 0 : attachedSlide ? -card.height : floatSlide ? -10 : unfold ? -24 : quickFade ? -2 : -4
    readonly property real hiddenOpacity: attachedSlide ? 1.0 : floatSlide ? 0.72 : quickFade ? 0.0 : 0.0
    readonly property real hiddenScale: attachedSlide ? 1.0 : quickFade ? 0.985 : unfold ? 0.98 : 0.96
    readonly property int motionDuration: quickFade ? 190 : unfold ? 220 : 180
    readonly property bool moduleAnchored: !popupAttachToBar && anchorCenterX >= 0 && frozenLeft >= 0

    function freezeAnchor() {
        const outW = screen ? screen.width : 0;
        root.frozenLeft = PopupAnchor.clampedLeft(root.anchorCenterX, root.implicitWidth, outW, root.barMargin);
    }

    default property alias body: contentColumn.data
    property alias background: bgContainer.data

    function prewarm() {
        if (root.suppressPrewarm || !root.ready || !root.attachedSlide || root.active)
            return;
        root.frozenHeight = Math.max(1, root.contentHeight);
        root.poseLocked = true;
        root.warming = true;
        warmTimer.restart();
    }

    onSuppressPrewarmChanged: {
        if (!root.suppressPrewarm)
            return;
        warmTimer.stop();
        root.warming = false;
        root.poseLocked = false;
        if (!root.active)
            root.frozenHeight = 0;
    }

    function open() {
        root.ready = true;
        openTimer.stop();
        showTimer.stop();
        warmTimer.stop();
        root.warming = false;
        if (!root.attachedSlide)
            root.freezeAnchor();
        if (root.attachedSlide) {
            root.frozenHeight = Math.max(1, root.contentHeight);
            root.poseLocked = true;
            root.opening = true;
            root.closing = false;
            root.shown = false;
            openTimer.restart();
            return;
        }
        root.poseLocked = false;
        root.closing = false;
        root.opening = false;
        root.shown = true;
        root.frozenHeight = 0;
    }
    function close() {
        openTimer.stop();
        showTimer.stop();
        warmTimer.stop();
        root.warming = false;
        root.poseLocked = false;
        root.shown = false;
        root.opening = false;
        root.closing = false;
        root.frozenHeight = 0;
    }

    onPopupAttachToBarChanged: root.prewarm()
    onPopupAnimationStyleChanged: root.prewarm()
    function toggle() {
        if (root.shown)
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
        if (root.warming || root.opening)
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
            // Theme apply usually lands before ready with suppressPrewarm, so the
            // attach/style change handlers never prewarm on startup. Map once now
            // (off-screen, Behaviors disabled via poseLocked) so the first click
            // does not also pay layershell surface creation mid-animation.
            root.prewarm();
        }
    }

    Timer {
        id: warmTimer
        interval: 120
        repeat: false
        onTriggered: {
            root.warming = false;
            root.poseLocked = false;
            root.frozenHeight = 0;
        }
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
            x: root.shown ? 0 : root.hiddenX
            y: root.shown ? 0 : root.hiddenY
            opacity: root.shown ? 1.0 : root.hiddenOpacity
            scale: root.shown ? 1.0 : root.hiddenScale
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
                    easing.type: Easing.InOutCubic
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
