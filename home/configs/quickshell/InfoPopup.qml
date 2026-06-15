import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool shown: false
    property string title: ""
    property string popupPosition: "right"
    property int topMargin: 64
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
    property string popupAnimationStyle: "softPop"
    property bool warming: false
    property bool opening: false
    property bool closing: false
    property int frozenHeight: 0
    readonly property string effectiveAnimationStyle: popupAttachToBar ? "attachedSlide" : popupAnimationStyle
    readonly property bool attachedSlide: effectiveAnimationStyle === "attachedSlide"
    readonly property bool quickFade: effectiveAnimationStyle === "quickFade"
    readonly property bool floatSlide: effectiveAnimationStyle === "floatSlide"
    readonly property bool unfold: effectiveAnimationStyle === "unfold"
    readonly property bool active: shown || opening || closing
    readonly property bool mapped: active || warming
    readonly property int cardRadius: flatMode ? 0 : 15
    readonly property int contentHeight: outerColumn.implicitHeight + 28
    readonly property int hiddenY: attachedSlide ? -card.height : floatSlide ? -10 : unfold ? -24 : quickFade ? 0 : -4
    readonly property real hiddenOpacity: attachedSlide ? 1.0 : floatSlide ? 0.72 : 0.0
    readonly property real hiddenScale: attachedSlide || quickFade ? 1.0 : unfold ? 0.98 : 0.96
    readonly property int motionDuration: quickFade ? 130 : unfold ? 220 : 180
    default property alias body: contentColumn.data

    function prewarm() {
        if (!root.attachedSlide || root.active)
            return;
        root.frozenHeight = Math.max(1, root.contentHeight);
        root.warming = true;
        warmTimer.restart();
    }

    function open() {
        closeTimer.stop();
        openTimer.stop();
        warmTimer.stop();
        root.warming = false;
        if (root.attachedSlide) {
            root.frozenHeight = Math.max(1, root.contentHeight);
            root.opening = true;
            root.closing = false;
            root.shown = false;
            openTimer.restart();
            return;
        }
        root.closing = false;
        root.opening = false;
        root.shown = true;
        root.frozenHeight = 0;
    }
    function close() {
        openTimer.stop();
        warmTimer.stop();
        root.warming = false;
        if (root.shown || root.opening) {
            root.frozenHeight = Math.max(1, root.implicitHeight);
            root.closing = true;
            root.opening = false;
            root.shown = false;
            closeTimer.restart();
        } else {
            root.shown = false;
            root.opening = false;
            root.closing = false;
            root.frozenHeight = 0;
        }
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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    visible: mapped
    anchors {
        top: true
        right: root.popupPosition === "right"
        left: root.popupPosition === "left"
    }
    margins {
        top: root.topMargin
        right: root.popupPosition === "right" ? 10 : 0
        left: root.popupPosition === "left" ? 10 : 0
    }
    implicitWidth: 300
    implicitHeight: (root.warming || root.opening || root.closing) ? root.frozenHeight : root.contentHeight
    exclusiveZone: -1
    color: "transparent"

    Timer {
        id: closeTimer
        interval: root.motionDuration + 50
        repeat: false
        onTriggered: {
            root.closing = false;
            root.frozenHeight = 0;
        }
    }

    Timer {
        id: warmTimer
        interval: 120
        repeat: false
        onTriggered: {
            root.warming = false;
            root.frozenHeight = 0;
        }
    }

    Timer {
        id: openTimer
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
            y: root.shown ? 0 : root.hiddenY
            opacity: root.shown ? 1.0 : root.hiddenOpacity
            scale: root.shown ? 1.0 : root.hiddenScale
            transformOrigin: root.popupPosition === "left" ? Item.TopLeft : Item.TopRight
            Behavior on y {
                enabled: root.effectiveAnimationStyle !== "quickFade"
                NumberAnimation {
                    duration: root.motionDuration
                    easing.type: Easing.InOutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: root.motionDuration
                    easing.type: root.quickFade ? Easing.OutCubic : Easing.InOutCubic
                }
            }
            Behavior on scale {
                enabled: !root.attachedSlide
                NumberAnimation {
                    duration: root.motionDuration
                    easing.type: Easing.InOutCubic
                }
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
