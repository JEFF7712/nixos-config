import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property string confirmedText: ""
    property string tentativeText: ""
    property bool shown: false

    // Full-screen transparent window (same pattern as quickshell-launcher / quickshell-switcher)
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    visible: shown
    color: "transparent"
    focusable: false

    WlrLayershell.namespace: "quickshell-xhisper-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Pill positioned at bottom-center
    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        radius: 14
        color: "#cc171b22"
        border.color: "#5588c0d0"
        border.width: 1
        width: Math.min(textRow.implicitWidth + 32, parent.width * 0.7)
        height: textRow.implicitHeight + 18

        opacity: root.shown ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        RowLayout {
            id: textRow
            anchors.centerIn: parent
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.confirmedText
                color: "#eceff4"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.tentativeText
                color: "#aeb7c5"
                font.italic: true
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
            }
        }
    }

    SocketServer {
        id: overlayServer
        active: true
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/xhisper-overlay.sock"

        handler: Component {
            Socket {
                parser: SplitParser {
                    splitMarker: "\n"
                    onRead: function(msg) {
                        if (msg.trim().length === 0) return;
                        try {
                            var obj = JSON.parse(msg);
                            if (obj.type === "partial") {
                                root.confirmedText = obj.confirmed || "";
                                root.tentativeText = obj.tentative || "";
                                root.shown = true;
                            } else if (obj.type === "hide" || obj.type === "final") {
                                root.shown = false;
                                root.confirmedText = "";
                                root.tentativeText = "";
                            } else if (obj.type === "error") {
                                root.confirmedText = "⚠ " + (obj.msg || "error");
                                root.tentativeText = "";
                                root.shown = true;
                                hideTimer.restart();
                            }
                        } catch (e) {
                            console.warn("xhisper overlay: bad JSON:", msg);
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 2000
        repeat: false
        onTriggered: root.shown = false
    }
}
