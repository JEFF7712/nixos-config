import QtQuick

InfoPopup {
    id: root
    title: "AUDIO"

    property string volumeLevel: "-"
    property bool muted: false

    signal setVolume(int percent)
    signal toggleMute
    signal openMixer

    function volumePercent() {
        const parsed = parseInt(String(root.volumeLevel).replace("%", ""));
        return isNaN(parsed) ? 0 : Math.max(0, Math.min(100, parsed));
    }

    function volumeIcon() {
        const percent = root.volumePercent();
        if (root.muted || percent <= 0)
            return "󰖁";
        if (percent < 34)
            return "󰕿";
        if (percent < 67)
            return "󰖀";
        return "󰕾";
    }

    function statusLabel() {
        if (root.muted)
            return "muted";
        if (root.volumeLevel === "-")
            return "output unavailable";
        return root.volumeLevel + " output";
    }

    function statusMeta() {
        if (root.muted)
            return "manual mute enabled";
        if (root.volumeLevel === "-")
            return "";
        return "default sink";
    }

    function sliderPercent(localX, trackWidth) {
        if (trackWidth <= 0)
            return root.volumePercent();
        return Math.max(0, Math.min(100, Math.round(localX * 100 / trackWidth)));
    }

    Item {
        width: parent.width
        height: 38

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: root.statusLabel()
                color: root.themeFg
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 12
                    weight: Font.Medium
                }
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.statusMeta()
                visible: text !== ""
                color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.44)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 9
                }
                elide: Text.ElideRight
            }
        }
    }

    Item {
        width: parent.width
        height: 30

        Text {
            id: labelText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "level"
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.55)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
            }
        }

        Rectangle {
            id: sliderTrack
            anchors.left: labelText.right
            anchors.right: valueText.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 6
            radius: 3
            color: root.pillBg

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * root.volumePercent() / 100
                height: parent.height
                radius: parent.radius
                color: root.muted ? Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.34) : Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.72)
                Behavior on width {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                width: 12
                height: 12
                radius: 6
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, parent.width * root.volumePercent() / 100 - width / 2))
                color: root.muted ? Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.58) : root.themeAccent
                border.width: 1
                border.color: root.themeRawBg
                Behavior on x {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => root.setVolume(root.sliderPercent(mouse.x - 8, sliderTrack.width))
                onPositionChanged: mouse => {
                    if (pressed)
                        root.setVolume(root.sliderPercent(mouse.x - 8, sliderTrack.width));
                }
            }
        }

        Text {
            id: valueText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.volumeLevel
            color: root.themeFg
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
                weight: Font.Medium
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    Row {
        width: parent.width
        height: 30
        spacing: 6

        AudioButton {
            width: 106
            icon: root.volumeIcon()
            label: root.muted ? "muted" : "mute"
            active: root.muted
            themeFg: root.themeFg
            themeAccent: root.themeAccent
            pillBg: root.pillBg
            pillBorder: root.pillBorder
            flatMode: root.flatMode
            onActivated: root.toggleMute()
        }

        AudioButton {
            width: parent.width - 112
            icon: "󰓃"
            label: "mixer"
            themeFg: root.themeFg
            themeAccent: root.themeAccent
            pillBg: root.pillBg
            pillBorder: root.pillBorder
            flatMode: root.flatMode
            onActivated: root.openMixer()
        }
    }

    component AudioButton: Item {
        id: buttonRoot
        property string icon: ""
        property string label: ""
        property bool active: false
        property color themeFg: "#ffffff"
        property color themeAccent: "#ffffff"
        property color pillBg: Qt.rgba(1, 1, 1, 0.05)
        property color pillBorder: Qt.rgba(1, 1, 1, 0.1)
        property bool flatMode: false
        signal activated

        height: parent.height

        function backgroundColor() {
            if (buttonRoot.active)
                return Qt.rgba(buttonRoot.themeAccent.r, buttonRoot.themeAccent.g, buttonRoot.themeAccent.b, 0.18);
            if (buttonMouse.pressed)
                return Qt.rgba(1, 1, 1, 0.08);
            if (buttonMouse.containsMouse)
                return Qt.rgba(1, 1, 1, 0.05);
            return buttonRoot.pillBg;
        }

        function borderColor() {
            if (buttonRoot.active)
                return Qt.rgba(buttonRoot.themeAccent.r, buttonRoot.themeAccent.g, buttonRoot.themeAccent.b, 0.38);
            return buttonRoot.pillBorder;
        }

        function foregroundColor(alpha) {
            if (buttonRoot.active)
                return buttonRoot.themeAccent;
            return Qt.rgba(buttonRoot.themeFg.r, buttonRoot.themeFg.g, buttonRoot.themeFg.b, alpha);
        }

        Rectangle {
            anchors.fill: parent
            radius: buttonRoot.flatMode ? 0 : 6
            color: buttonRoot.backgroundColor()
            border.width: 1
            border.color: buttonRoot.borderColor()
            Behavior on color {
                ColorAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: buttonRoot.label === "" ? 0 : 6

            Text {
                text: buttonRoot.icon
                color: buttonRoot.foregroundColor(0.7)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 12
                }
            }

            Text {
                visible: buttonRoot.label !== ""
                text: buttonRoot.label
                color: buttonRoot.foregroundColor(0.78)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 10
                    weight: buttonRoot.active ? Font.Medium : Font.Normal
                }
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: buttonRoot.activated()
        }
    }
}
