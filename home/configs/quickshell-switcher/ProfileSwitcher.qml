import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool shown: false
    property var profiles: []
    property string activeProfile: ""
    property int focusedIndex: -1

    function open() {
        listProc.running = true;
        activeProc.running = true;
        shown = true;
    }
    function close() {
        shown = false;
        focusedIndex = -1;
    }
    function toggle() {
        if (shown)
            close();
        else
            open();
    }

    function activate(name) {
        // Detach with setsid -f and redirect all stdio so the child survives
        // switch-profile's pkill-quickshell and can't be killed by SIGPIPE.
        switchProc.command = ["bash", "-c", "setsid -f switch-profile \"$1\" </dev/null >/dev/null 2>&1", "--", name];
        switchProc.running = true;
        close();
    }

    IpcHandler {
        target: "profile"
        function toggle(): void {
            root.toggle();
        }
        function show(): void {
            root.open();
        }
        function hide(): void {
            root.close();
        }
    }

    WlrLayershell.namespace: "quickshell-profile-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    visible: shown
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "transparent"

    Process {
        id: listProc
        command: ["sh", "-c", "for d in \"$HOME\"/.config/desktop-profiles/*/; do [ -d \"$d\" ] && basename \"$d\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(s => s.trim()).filter(s => s.length > 0);
                root.profiles = lines;
            }
        }
    }

    Process {
        id: activeProc
        command: ["sh", "-c", "cat \"$HOME\"/.config/desktop-profiles/active 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.activeProfile = text.trim();
            }
        }
    }

    Process {
        id: switchProc
        command: ["true"]
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }
    Shortcut {
        sequence: "Return"
        onActivated: if (root.focusedIndex >= 0)
            root.activate(root.profiles[root.focusedIndex])
    }
    Shortcut {
        sequence: "Right"
        onActivated: root.focusedIndex = Math.min(root.profiles.length - 1, Math.max(0, root.focusedIndex) + 1)
    }
    Shortcut {
        sequence: "Left"
        onActivated: root.focusedIndex = Math.max(0, (root.focusedIndex < 0 ? 1 : root.focusedIndex) - 1)
    }
    Shortcut {
        sequence: "Down"
        onActivated: root.focusedIndex = Math.min(root.profiles.length - 1, (root.focusedIndex < 0 ? 0 : root.focusedIndex) + grid.columns)
    }
    Shortcut {
        sequence: "Up"
        onActivated: root.focusedIndex = Math.max(0, (root.focusedIndex < 0 ? 0 : root.focusedIndex) - grid.columns)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.78, grid.implicitWidth + 36)
        height: grid.implicitHeight + 36
        radius: 18
        color: Qt.rgba(0.08, 0.08, 0.08, 0.32)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.96
        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            SpringAnimation {
                spring: 3.5
                damping: 0.55
                mass: 0.7
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        Grid {
            id: grid
            anchors.centerIn: parent
            columns: 3
            rowSpacing: 14
            columnSpacing: 14

            Repeater {
                model: root.profiles

                Item {
                    id: tile
                    width: 240
                    height: 165

                    property bool hovered: tileMouse.containsMouse
                    property bool isActive: modelData === root.activeProfile
                    property bool isFocused: index === root.focusedIndex
                    property bool highlight: hovered || isFocused

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "transparent"
                        border.width: 1
                        border.color: tile.highlight ? Qt.rgba(1, 1, 1, 0.85) : (tile.isActive ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.10))
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 4
                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: mask
                            maskThresholdMin: 0.5
                        }

                        Image {
                            anchors.fill: parent
                            source: Qt.resolvedUrl(Quickshell.env("HOME") + "/nixos-assets/previews/" + modelData + ".png")
                            fillMode: Image.PreserveAspectCrop
                            cache: true
                            asynchronous: true
                            smooth: true
                        }
                    }

                    Item {
                        id: mask
                        anchors.fill: parent
                        anchors.margins: 4
                        layer.enabled: true
                        visible: false
                        Rectangle {
                            anchors.fill: parent
                            radius: 7
                            color: "white"
                        }
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 8
                        text: modelData
                        color: "white"
                        opacity: tile.highlight ? 1.0 : 0.78
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.weight: tile.isActive ? Font.Medium : Font.Normal
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.55)
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.focusedIndex = index
                        onClicked: root.activate(modelData)
                    }
                }
            }
        }
    }
}
