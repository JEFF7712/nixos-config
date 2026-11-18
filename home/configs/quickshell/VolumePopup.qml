import QtQuick
import "services" as Services

InfoPopup {
    id: root
    title: "AUDIO"

    required property Services.AudioService audioService
    property color themeWarm: "#e6dcc6"
    property color themeFresh: "#d6eadc"
    readonly property string volumeLevel: audioService.available ? audioService.volumePercent + "%" : "-"
    readonly property bool muted: audioService.muted
    readonly property string sourceLevel: audioService.sourceAvailable ? audioService.sourceVolumePercent + "%" : "-"
    readonly property bool sourceMuted: audioService.sourceMuted

    function volumePercent() {
        const parsed = parseInt(String(root.volumeLevel).replace("%", ""));
        return isNaN(parsed) ? 0 : Math.max(0, Math.min(100, parsed));
    }

    function sourcePercent() {
        const parsed = parseInt(String(root.sourceLevel).replace("%", ""));
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

    function micIcon() {
        if (root.sourceMuted || root.sourcePercent() <= 0)
            return "󰍭";
        return "󰍬";
    }

    function outputKindIcon(kind) {
        if (kind === "bluetooth")
            return "󰂯";
        if (kind === "hdmi")
            return "󰍹";
        return "󰓃";
    }

    function statusLabel() {
        if (root.audioService.activeOutputLabel !== "")
            return root.audioService.activeOutputLabel;
        if (root.muted)
            return "muted";
        if (root.volumeLevel === "-")
            return "output unavailable";
        return root.volumeLevel + " output";
    }

    function statusMeta() {
        if (root.muted)
            return "muted · output";
        if (root.volumeLevel === "-")
            return "";
        return root.volumeLevel + " · default output";
    }

    function micStatusMeta() {
        if (root.sourceMuted)
            return "muted" + (root.audioService.micCaptureActive ? " · app listening" : "");
        if (root.audioService.micCaptureActive)
            return root.sourceLevel + " · live capture";
        return root.sourceLevel + " · default input";
    }

    function sliderPercent(localX, trackWidth, fallback) {
        if (trackWidth <= 0)
            return fallback;
        return Math.max(0, Math.min(100, Math.round(localX * 100 / trackWidth)));
    }

    Item {
        width: parent.width
        height: 38

        Column {
            anchors.left: parent.left
            anchors.right: rtpBadge.visible ? rtpBadge.left : parent.right
            anchors.rightMargin: rtpBadge.visible ? 8 : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: root.statusLabel()
                color: root.themeFg
                font {
                    family: root.barFont
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
                    family: root.barFont
                    pixelSize: 9
                }
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: rtpBadge
            visible: root.audioService.rtpMirrorActive
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 18
            width: rtpBadgeLabel.implicitWidth + 12
            radius: root.flatMode ? 0 : 9
            color: Qt.rgba(root.themeFresh.r, root.themeFresh.g, root.themeFresh.b, 0.16)
            border.width: root.flatMode ? 0 : 1
            border.color: Qt.rgba(root.themeFresh.r, root.themeFresh.g, root.themeFresh.b, 0.42)

            Text {
                id: rtpBadgeLabel
                anchors.centerIn: parent
                text: "󰓃 RTP · nas-01"
                color: root.themeFresh
                font {
                    family: root.barFont
                    pixelSize: 8
                    weight: Font.Medium
                }
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
            text: "out"
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.55)
            font {
                family: root.barFont
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
            radius: root.flatMode ? 0 : 3
            color: root.flatMode ? Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.15) : root.pillBg

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * root.volumePercent() / 100
                height: parent.height
                radius: parent.radius
                color: root.muted ? Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.34) : root.flatMode ? root.themeAccent : Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.72)
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
                visible: !root.flatMode
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
                onPressed: mouse => root.audioService.setVolume(root.sliderPercent(mouse.x - 8, sliderTrack.width, root.volumePercent()))
                onPositionChanged: mouse => {
                    if (pressed)
                        root.audioService.setVolume(root.sliderPercent(mouse.x - 8, sliderTrack.width, root.volumePercent()));
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
                family: root.barFont
                pixelSize: 10
                weight: Font.Medium
            }
        }
    }

    Row {
        width: parent.width
        height: 28
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
            onActivated: root.audioService.toggleMute()
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
            onActivated: root.audioService.openMixer()
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
        visible: root.audioService.outputs.count > 1
    }

    Text {
        width: parent.width
        text: "OUTPUTS"
        visible: root.audioService.outputs.count > 1
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.42)
        font {
            family: root.barFont
            pixelSize: 8
            weight: Font.Medium
        }
    }

    Repeater {
        model: root.audioService.outputs.count > 1 ? root.audioService.outputs : 0

        delegate: DeviceRow {
            width: parent.width
            glyph: root.outputKindIcon(model.kind)
            label: model.label
            selected: model.active
            onActivated: root.audioService.selectOutput(model.name)
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
        visible: root.audioService.sourceAvailable
    }

    Item {
        width: parent.width
        height: 30
        visible: root.audioService.sourceAvailable

        Column {
            anchors.left: parent.left
            anchors.right: micMuteBtn.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Row {
                spacing: 6

                Text {
                    text: root.audioService.activeInputLabel !== "" ? root.audioService.activeInputLabel : "Microphone"
                    color: root.themeFg
                    font {
                        family: root.barFont
                        pixelSize: 10
                        weight: Font.Medium
                    }
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: 6
                    height: 6
                    radius: root.flatMode ? 0 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.audioService.micCaptureActive
                    color: root.themeWarm
                }
            }

            Text {
                width: parent.width
                text: root.micStatusMeta()
                color: root.audioService.micCaptureActive && !root.sourceMuted ? root.themeWarm : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.44)
                font {
                    family: root.barFont
                    pixelSize: 8
                }
                elide: Text.ElideRight
            }
        }

        AudioButton {
            id: micMuteBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 72
            height: 24
            icon: root.micIcon()
            label: root.sourceMuted ? "off" : "mic"
            active: root.sourceMuted
            themeFg: root.themeFg
            themeAccent: root.themeAccent
            pillBg: root.pillBg
            pillBorder: root.pillBorder
            flatMode: root.flatMode
            onActivated: root.audioService.toggleSourceMute()
        }
    }

    Item {
        width: parent.width
        height: 26
        visible: root.audioService.sourceAvailable

        Text {
            id: micLabelText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "mic"
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.55)
            font {
                family: root.barFont
                pixelSize: 10
            }
        }

        Rectangle {
            id: micSliderTrack
            anchors.left: micLabelText.right
            anchors.right: micValueText.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 6
            radius: root.flatMode ? 0 : 3
            color: root.flatMode ? Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.15) : root.pillBg

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * root.sourcePercent() / 100
                height: parent.height
                radius: parent.radius
                color: root.sourceMuted ? Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.34) : root.flatMode ? root.themeAccent : Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.72)
                Behavior on width {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                visible: !root.flatMode
                width: 12
                height: 12
                radius: 6
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, parent.width * root.sourcePercent() / 100 - width / 2))
                color: root.sourceMuted ? Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.58) : root.themeAccent
                border.width: 1
                border.color: root.themeRawBg
                Behavior on x {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => root.audioService.setSourceVolume(root.sliderPercent(mouse.x - 8, micSliderTrack.width, root.sourcePercent()))
                onPositionChanged: mouse => {
                    if (pressed)
                        root.audioService.setSourceVolume(root.sliderPercent(mouse.x - 8, micSliderTrack.width, root.sourcePercent()));
                }
            }
        }

        Text {
            id: micValueText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.sourceLevel
            color: root.themeFg
            font {
                family: root.barFont
                pixelSize: 10
                weight: Font.Medium
            }
        }
    }

    Text {
        width: parent.width
        text: "INPUTS"
        visible: root.audioService.inputs.count > 1
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.42)
        font {
            family: root.barFont
            pixelSize: 8
            weight: Font.Medium
        }
    }

    Repeater {
        model: root.audioService.inputs.count > 1 ? root.audioService.inputs : 0

        delegate: DeviceRow {
            width: parent.width
            glyph: "󰍬"
            label: model.label
            selected: model.active
            onActivated: root.audioService.selectInput(model.name)
        }
    }

    component DeviceRow: Item {
        id: devRow
        property string glyph: "󰓃"
        property string label: ""
        property bool selected: false
        signal activated

        height: 28

        Rectangle {
            anchors.fill: parent
            radius: root.flatMode ? 0 : 6
            color: root.flatMode ? "transparent" : devRow.selected ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.14) : devMouse.pressed ? Qt.rgba(1, 1, 1, 0.08) : devMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }

        Text {
            id: devIcon
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: devRow.glyph
            color: devRow.selected || (root.flatMode && devMouse.containsMouse) ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.62)
            font {
                family: root.barFont
                pixelSize: 11
            }
        }

        Text {
            anchors.left: devIcon.right
            anchors.right: devActiveTag.left
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: devRow.label
            color: devRow.selected || (root.flatMode && devMouse.containsMouse) ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.86)
            font {
                family: root.barFont
                pixelSize: 10
                weight: devRow.selected ? Font.Medium : Font.Normal
            }
            elide: Text.ElideRight
        }

        Text {
            id: devActiveTag
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: devRow.selected ? "on" : ""
            color: root.themeAccent
            font {
                family: root.barFont
                pixelSize: 9
                weight: Font.Medium
            }
        }

        MouseArea {
            id: devMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: devRow.selected ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                if (!devRow.selected)
                    devRow.activated();
            }
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
            if (buttonRoot.flatMode)
                return "transparent";
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
            if (buttonRoot.active || (buttonRoot.flatMode && (buttonMouse.containsMouse || buttonMouse.pressed)))
                return buttonRoot.themeAccent;
            return Qt.rgba(buttonRoot.themeFg.r, buttonRoot.themeFg.g, buttonRoot.themeFg.b, alpha);
        }

        Rectangle {
            anchors.fill: parent
            radius: buttonRoot.flatMode ? 0 : 6
            color: buttonRoot.backgroundColor()
            border.width: buttonRoot.flatMode ? 0 : 1
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
                    family: root.barFont
                    pixelSize: 12
                }
            }

            Text {
                visible: buttonRoot.label !== ""
                text: buttonRoot.label
                color: buttonRoot.foregroundColor(0.78)
                font {
                    family: root.barFont
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
