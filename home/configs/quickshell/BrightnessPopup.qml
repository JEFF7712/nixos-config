import QtQuick
import "services" as Services

InfoPopup {
    id: root
    title: "BRIGHTNESS"

    required property Services.BrightnessService brightnessService

    function statusLabel() {
        const count = root.brightnessService.displays.count;
        if (!root.brightnessService.available)
            return "no displays found";
        const unit = count === 1 ? "display" : "displays";
        return count + " " + unit + " · avg " + root.brightnessService.averagePercent + "%";
    }

    function statusMeta() {
        if (root.brightnessService.lastError !== "")
            return root.brightnessService.lastError;
        if (root.brightnessService.busy)
            return "updating";
        if (!root.brightnessService.available)
            return "";
        return "laptop panel + DDC monitors";
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

    Column {
        id: sliderColumn
        width: parent.width
        spacing: 10

        Repeater {
            model: root.brightnessService.displays

            delegate: Item {
                id: rowRoot
                width: sliderColumn.width
                height: 30

                property int dragPercent: -1

                function shownPercent() {
                    if (rowRoot.dragPercent >= 0)
                        return rowRoot.dragPercent;
                    return Math.max(0, Math.min(100, model.percent));
                }

                function sliderPercent(localX, trackWidth) {
                    if (trackWidth <= 0)
                        return rowRoot.shownPercent();
                    return Math.max(0, Math.min(100, Math.round(localX * 100 / trackWidth)));
                }

                function applyAt(localX, trackWidth) {
                    const pct = rowRoot.sliderPercent(localX, trackWidth);
                    rowRoot.dragPercent = pct;
                    root.brightnessService.setBrightness(model.id, pct);
                }

                Text {
                    id: labelText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 118
                    text: model.label
                    color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.55)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 10
                    }
                    elide: Text.ElideRight
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
                        width: parent.width * rowRoot.shownPercent() / 100
                        height: parent.height
                        radius: parent.radius
                        color: root.flatMode ? root.themeAccent : Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.72)
                        Behavior on width {
                            enabled: rowRoot.dragPercent < 0
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
                        x: Math.max(0, Math.min(parent.width - width, parent.width * rowRoot.shownPercent() / 100 - width / 2))
                        color: root.themeAccent
                        border.width: 1
                        border.color: root.themeRawBg
                        Behavior on x {
                            enabled: rowRoot.dragPercent < 0
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
                        onPressed: mouse => rowRoot.applyAt(mouse.x - 8, sliderTrack.width)
                        onPositionChanged: mouse => {
                            if (pressed)
                                rowRoot.applyAt(mouse.x - 8, sliderTrack.width);
                        }
                        onReleased: rowRoot.dragPercent = -1
                        onCanceled: rowRoot.dragPercent = -1
                    }
                }

                Text {
                    id: valueText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    horizontalAlignment: Text.AlignRight
                    text: rowRoot.shownPercent() + "%"
                    color: root.themeFg
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 10
                        weight: Font.Medium
                    }
                }
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

        PopupButton {
            width: parent.width
            icon: "󰑓"
            label: "refresh"
            themeFg: root.themeFg
            themeAccent: root.themeAccent
            pillBg: root.pillBg
            pillBorder: root.pillBorder
            flatMode: root.flatMode
            onActivated: root.brightnessService.refresh()
        }
    }

    component PopupButton: Item {
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

        Rectangle {
            anchors.fill: parent
            radius: buttonRoot.flatMode ? 0 : 6
            color: buttonRoot.backgroundColor()
            border.width: buttonRoot.flatMode ? 0 : 1
            border.color: buttonRoot.borderColor()
        }

        Row {
            anchors.centerIn: parent
            spacing: buttonRoot.label === "" ? 0 : 6

            Text {
                text: buttonRoot.icon
                color: Qt.rgba(buttonRoot.themeFg.r, buttonRoot.themeFg.g, buttonRoot.themeFg.b, 0.7)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 12
                }
            }

            Text {
                visible: buttonRoot.label !== ""
                text: buttonRoot.label
                color: Qt.rgba(buttonRoot.themeFg.r, buttonRoot.themeFg.g, buttonRoot.themeFg.b, 0.78)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 10
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
