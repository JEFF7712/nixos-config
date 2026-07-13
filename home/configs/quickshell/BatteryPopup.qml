import QtQuick
import "services" as Services

InfoPopup {
    id: root
    title: "BATTERY"

    required property Services.PowerService powerService
    readonly property string charge: powerService.available ? powerService.chargePercent + "%" : "-"
    readonly property string status_: powerService.state === "unknown" ? "-" : powerService.state === "full" ? "fully charged" : powerService.state.replace(/-/g, " ")
    readonly property string timeLeft: formatDuration(powerService.secondsRemaining)
    readonly property string draw: powerService.available ? formatScalar(powerService.drawWatts) + " W" : "-"
    readonly property string health: powerService.available && powerService.healthPercent > 0 ? powerService.healthPercent + "%" : "-"
    readonly property var profileOptions: [
        {
            "id": "power-saver",
            "icon": "󰌪",
            "label": "save"
        },
        {
            "id": "balanced",
            "icon": "󰾅",
            "label": "balanced"
        },
        {
            "id": "performance",
            "icon": "󱐋",
            "label": "perf"
        }
    ]

    function percent(value) {
        const parsed = parseInt(String(value).replace("%", ""));
        return isNaN(parsed) ? 0 : Math.max(0, Math.min(100, parsed));
    }

    function hasBattery() {
        return root.powerService.available;
    }

    function formatScalar(value) {
        return Number(value).toFixed(1).replace(/\.0$/, "");
    }

    function formatDuration(seconds) {
        if (seconds <= 0)
            return "";
        if (seconds >= 3600)
            return root.formatScalar(seconds / 3600) + " hours";
        return Math.round(seconds / 60) + " minutes";
    }

    function statusLabel() {
        if (!root.hasBattery())
            return "battery unavailable";
        if (root.status_ === "-")
            return root.charge;
        return root.charge + " " + root.status_;
    }

    function statusMeta() {
        const parts = [];
        if (root.timeLeft !== "")
            parts.push(root.timeLeft);
        if (root.draw !== "-")
            parts.push(root.draw);
        return parts.join("  ");
    }

    function profileLabel() {
        if (root.powerService.profile === "power-saver")
            return "power saver";
        if (root.powerService.profile === "performance")
            return "performance";
        if (root.powerService.profile === "balanced")
            return "balanced";
        return "profile unavailable";
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
                color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.44)
                visible: text !== ""
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 9
                }
                elide: Text.ElideRight
            }
        }
    }

    MeterRow {
        label: "charge"
        value: root.charge
        amount: root.percent(root.charge)
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        pillBg: root.pillBg
    }

    MeterRow {
        label: "health"
        value: root.health
        amount: root.percent(root.health)
        visible: root.health !== "-"
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        pillBg: root.pillBg
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    InfoRow {
        label: "profile"
        value: root.profileLabel()
        themeFg: root.themeFg
        active: root.shown
    }

    Row {
        width: parent.width
        height: 28
        spacing: 6

        Repeater {
            model: root.profileOptions

            Item {
                required property var modelData

                width: (parent.width - 12) / 3
                height: parent.height

                readonly property bool selected: root.powerService.profile === modelData.id

                Rectangle {
                    anchors.fill: parent
                    radius: root.flatMode ? 0 : 6
                    color: parent.selected ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.18) : profileMouse.pressed ? Qt.rgba(1, 1, 1, 0.08) : profileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : root.pillBg
                    border.width: 1
                    border.color: parent.selected ? Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.38) : root.pillBorder
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
                    spacing: 5

                    Text {
                        text: modelData.icon
                        color: parent.parent.selected ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.64)
                        font {
                            family: "JetBrainsMono Nerd Font"
                            pixelSize: 11
                        }
                    }

                    Text {
                        text: modelData.label
                        color: parent.parent.selected ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.74)
                        font {
                            family: "JetBrainsMono Nerd Font"
                            pixelSize: 9
                            weight: parent.parent.selected ? Font.Medium : Font.Normal
                        }
                    }
                }

                MouseArea {
                    id: profileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.powerService.setProfile(modelData.id)
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    InfoToggle {
        label: root.powerService.idleInhibited ? "idle inhibit on" : "idle inhibit off"
        checked: root.powerService.idleInhibited
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        dividerColor: root.dividerColor
        onToggled: root.powerService.toggleIdleInhibit()
    }

    Rectangle {
        width: parent.width
        height: 1
        visible: root.powerService.thresholdWritable
        color: root.dividerColor
    }

    InfoToggle {
        label: root.powerService.chargeLimit >= 100 ? "charge limit off" : "charge limit " + root.powerService.chargeLimit + "%"
        checked: root.powerService.chargeLimit < 100
        visible: root.powerService.thresholdWritable
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        themeRawBg: root.themeRawBg
        dividerColor: root.dividerColor
        onToggled: root.powerService.toggleChargeLimit()
    }

    component MeterRow: Item {
        id: rowRoot
        property string label: ""
        property string value: "-"
        property int amount: 0
        property color themeFg: "#ffffff"
        property color themeAccent: "#ffffff"
        property color pillBg: Qt.rgba(1, 1, 1, 0.05)

        width: parent.width
        height: 24

        Text {
            id: labelText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: rowRoot.label
            color: Qt.rgba(rowRoot.themeFg.r, rowRoot.themeFg.g, rowRoot.themeFg.b, 0.55)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
            }
        }

        Rectangle {
            anchors.left: labelText.right
            anchors.right: valueText.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 4
            radius: 2
            color: rowRoot.pillBg

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * Math.max(0, Math.min(100, rowRoot.amount)) / 100
                height: parent.height
                radius: parent.radius
                color: Qt.rgba(rowRoot.themeAccent.r, rowRoot.themeAccent.g, rowRoot.themeAccent.b, 0.72)
                Behavior on width {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Text {
            id: valueText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: rowRoot.value
            color: rowRoot.themeFg
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
                weight: Font.Medium
            }
        }
    }
}
