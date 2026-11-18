import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property color themeFg: "#ffffff"
    property color themeBg: "#cc2a2a2a"
    property color themeAccent: "#ffffff"
    property color themeWarm: "#e6dcc6"
    property color themeBorder: Qt.rgba(1, 1, 1, 0.24)
    property color innerHighlight: Qt.rgba(1, 1, 1, 0.06)
    property color pillBg: Qt.rgba(1, 1, 1, 0.08)
    property bool flatMode: false
    property int barRadius: 15
    property string barFont: "JetBrainsMono Nerd Font"
    property int osdMs: 120

    property bool shown: false
    property bool closing: false
    property string icon: "󰕾"
    property string label: ""
    property string badge: ""
    property int percent: -1
    property bool muted: false
    property real lastIpcMs: 0

    readonly property bool hasMeter: root.percent >= 0
    readonly property int cardRadius: root.flatMode ? 0 : Math.max(12, Math.min(20, root.barRadius))
    readonly property int animMs: Math.max(60, root.osdMs)

    function _present(nextIcon, nextLabel, nextBadge, nextPercent, nextMuted, fromIpc) {
        if (fromIpc)
            root.lastIpcMs = Date.now();
        root.icon = nextIcon;
        root.label = nextLabel;
        root.badge = nextBadge;
        root.percent = nextPercent;
        root.muted = nextMuted;
        closeTimer.stop();
        root.closing = false;
        root.shown = true;
        hideTimer.restart();
    }

    function ipcHandledRecently(): bool {
        return (Date.now() - root.lastIpcMs) < 400;
    }

    function showVolume(devLabel: string, value: int, isMuted: bool, fromIpc: bool): void {
        const clamped = Math.max(0, Math.min(100, Math.round(value)));
        let glyph = "󰕾";
        if (isMuted || clamped <= 0)
            glyph = "󰖁";
        else if (clamped < 34)
            glyph = "󰕿";
        else if (clamped < 67)
            glyph = "󰖀";
        root._present(glyph, devLabel || "Output", isMuted ? "muted" : (clamped + "%"), clamped, isMuted, fromIpc === true);
    }

    function showMic(devLabel: string, value: int, isMuted: bool, fromIpc: bool): void {
        const clamped = Math.max(0, Math.min(100, Math.round(value)));
        const glyph = (isMuted || clamped <= 0) ? "󰍭" : "󰍬";
        root._present(glyph, devLabel || "Microphone", isMuted ? "muted" : (clamped + "%"), clamped, isMuted, fromIpc === true);
    }

    function showBrightness(devLabel: string, value: int, fromIpc: bool): void {
        const clamped = Math.max(0, Math.min(100, Math.round(value)));
        let glyph = "󰃠";
        if (clamped < 34)
            glyph = "󰃞";
        else if (clamped < 67)
            glyph = "󰃟";
        root._present(glyph, devLabel || "Display", clamped + "%", clamped, false, fromIpc === true);
    }

    function showStatus(glyph: string, statusLabel: string, statusBadge: string): void {
        root._present(glyph || "󰋼", statusLabel || "System", statusBadge || "", -1, false, false);
    }

    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: root.shown || root.closing
    anchors {
        bottom: true
    }
    margins {
        bottom: 44
    }
    implicitWidth: 252
    implicitHeight: (root.shown || root.closing) ? (root.hasMeter ? 52 : 40) : 1
    exclusiveZone: -1
    color: "transparent"

    Timer {
        id: hideTimer
        interval: 1400
        repeat: false
        onTriggered: {
            root.shown = false;
            root.closing = true;
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: root.animMs
        repeat: false
        onTriggered: root.closing = false
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: card
            width: parent.width
            height: parent.height
            radius: root.cardRadius
            color: root.themeBg
            border.width: 1
            border.color: root.themeBorder
            opacity: root.shown ? 1.0 : 0.0
            y: root.shown ? 0 : 8
            scale: root.flatMode ? 1.0 : (root.shown ? 1.0 : 0.97)

            Behavior on opacity {
                NumberAnimation {
                    duration: root.animMs
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: root.animMs
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                enabled: !root.flatMode
                NumberAnimation {
                    duration: root.animMs
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                color: root.innerHighlight
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Text {
                    id: iconText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.icon
                    color: root.muted ? Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.45) : root.themeAccent
                    font {
                        family: root.barFont
                        pixelSize: 16
                    }
                }

                Column {
                    width: parent.width - iconText.implicitWidth - 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.hasMeter ? 6 : 0

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.right: badgeText.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.label
                            color: root.themeFg
                            font {
                                family: root.barFont
                                pixelSize: 10
                                weight: Font.Medium
                            }
                            elide: Text.ElideRight
                        }

                        Text {
                            id: badgeText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.badge
                            color: root.muted ? root.themeWarm : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.72)
                            font {
                                family: root.barFont
                                pixelSize: 10
                                weight: Font.Medium
                            }
                        }
                    }

                    Rectangle {
                        visible: root.hasMeter
                        width: parent.width
                        height: 4
                        radius: root.flatMode ? 0 : 2
                        color: root.flatMode ? Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.16) : root.pillBg

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * Math.max(0, Math.min(100, root.percent)) / 100
                            height: parent.height
                            radius: parent.radius
                            color: root.muted ? Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.34) : root.themeAccent
                            Behavior on width {
                                NumberAnimation {
                                    duration: Math.max(80, root.animMs)
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
