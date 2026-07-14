import QtQuick
import "services" as Services

InfoPopup {
    id: root
    title: "BLUETOOTH"

    required property Services.BluetoothService bluetoothService

    function statusLabel() {
        if (!root.bluetoothService.available)
            return "no adapter";
        if (!root.bluetoothService.enabled)
            return "bluetooth disabled";
        if (root.bluetoothService.connectedCount > 0)
            return root.bluetoothService.connectedCount + " connected";
        return "not connected";
    }

    function statusMeta() {
        if (!root.bluetoothService.available)
            return "bluez adapter unavailable";
        if (!root.bluetoothService.enabled)
            return "";
        if (root.bluetoothService.devices.count === 0)
            return "no paired devices";
        return root.bluetoothService.devices.count + " paired";
    }

    function deviceMeta(device) {
        if (device.connected)
            return "connected";
        return "paired";
    }

    function rowBackgroundColor(pressed, hovered) {
        if (pressed)
            return Qt.rgba(1, 1, 1, 0.08);
        if (hovered)
            return Qt.rgba(1, 1, 1, 0.05);
        return "transparent";
    }

    Item {
        width: parent.width
        height: 26

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - toggleRow.width - 10
            text: root.statusLabel()
            color: root.bluetoothService.enabled && root.bluetoothService.available ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.48)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 11
                weight: Font.Medium
            }
            elide: Text.ElideRight
        }

        Row {
            id: toggleRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            InfoToggle {
                width: 32
                label: ""
                checked: root.bluetoothService.enabled
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                themeRawBg: root.themeRawBg
                dividerColor: root.dividerColor
                onToggled: {
                    if (!root.bluetoothService.available)
                        return;
                    root.bluetoothService.setEnabled(!root.bluetoothService.enabled);
                }
            }
        }
    }

    Text {
        width: parent.width
        text: root.statusMeta()
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.42)
        font {
            family: "JetBrainsMono Nerd Font"
            pixelSize: 9
        }
        elide: Text.ElideRight
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
        visible: root.bluetoothService.enabled
    }

    Repeater {
        model: root.bluetoothService.enabled ? root.bluetoothService.devices : 0

        delegate: Item {
            id: deviceRow
            width: parent.width
            height: 36

            Rectangle {
                anchors.fill: parent
                radius: root.flatMode ? 0 : 6
                color: root.rowBackgroundColor(rowMouse.pressed, rowMouse.containsMouse)
                Behavior on color {
                    ColorAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                id: deviceIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 6
                text: model.connected ? "󰂱" : "󰂯"
                color: model.connected ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.62)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 12
                }
            }

            Column {
                anchors.left: deviceIcon.right
                anchors.right: stateText.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 1

                Text {
                    width: parent.width
                    text: model.name
                    color: model.connected ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.88)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 10
                        weight: model.connected ? Font.Medium : Font.Normal
                    }
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.deviceMeta(model)
                    color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.42)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 8
                    }
                    elide: Text.ElideRight
                }
            }

            Text {
                id: stateText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 6
                text: model.busy ? "..." : (model.connected ? "on" : "")
                color: model.connected ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.46)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 9
                    weight: Font.Medium
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: model.busy ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                onClicked: {
                    if (model.busy)
                        return;
                    root.bluetoothService.toggleDevice(model.id);
                }
            }
        }
    }

    Text {
        width: parent.width
        text: "no paired devices"
        visible: root.bluetoothService.enabled && root.bluetoothService.devices.count === 0
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.36)
        font {
            family: "JetBrainsMono Nerd Font"
            pixelSize: 9
            italic: true
        }
        horizontalAlignment: Text.AlignHCenter
        topPadding: 8
        bottomPadding: 8
    }
}
