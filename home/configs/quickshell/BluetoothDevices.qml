import QtQuick
import QtQuick.Shapes

Column {
    id: root

    required property var bluetoothService
    property color themeFg: "#ffffff"
    property color themeAccent: "#ffffff"
    property string barFont: "JetBrainsMono Nerd Font"
    property real labelOpacity: 0.65
    property real mutedOpacity: 0.4

    readonly property var connectedDevices: {
        const devices = [];
        if (!root.bluetoothService.available || !root.bluetoothService.enabled)
            return devices;
        const model = root.bluetoothService.devices;
        for (let i = 0; i < model.count; i++) {
            const device = model.get(i);
            if (device.connected) {
                devices.push({
                    name: device.name,
                    icon: device.icon,
                    batteryPercent: device.batteryPercent
                });
            }
        }
        return devices;
    }

    visible: connectedDevices.length > 0
    spacing: 16

    function deviceIcon(icon: string): string {
        if (icon.indexOf("headset") !== -1 || icon.indexOf("headphone") !== -1)
            return "";
        if (icon.indexOf("keyboard") !== -1)
            return "";
        if (icon.indexOf("mouse") !== -1)
            return "󰍽";
        if (icon.indexOf("audio") !== -1)
            return "󰓃";
        if (icon.indexOf("phone") !== -1)
            return "";
        if (icon.indexOf("gaming") !== -1 || icon.indexOf("gamepad") !== -1)
            return "";
        if (icon.indexOf("computer") !== -1)
            return "";
        if (icon.indexOf("camera") !== -1)
            return "";
        return "󰂯";
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.18)
    }

    Flow {
        width: parent.width
        spacing: 16

        Repeater {
            model: root.connectedDevices

            delegate: Column {
                id: deviceTile

                required property var modelData
                readonly property bool batteryKnown: modelData.batteryPercent >= 0

                width: Math.floor((root.width - 32) / 3)
                spacing: 6

                Item {
                    id: batteryRing
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 72
                    height: 72

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeWidth: 4
                            strokeColor: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.14)
                            fillColor: "transparent"

                            PathAngleArc {
                                centerX: batteryRing.width / 2
                                centerY: batteryRing.height / 2
                                radiusX: 32
                                radiusY: 32
                                startAngle: -90
                                sweepAngle: 360
                            }
                        }

                        ShapePath {
                            strokeWidth: 4
                            strokeColor: deviceTile.batteryKnown && deviceTile.modelData.batteryPercent > 0 ? root.themeAccent : "transparent"
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathAngleArc {
                                centerX: batteryRing.width / 2
                                centerY: batteryRing.height / 2
                                radiusX: 32
                                radiusY: 32
                                startAngle: -90
                                sweepAngle: deviceTile.batteryKnown ? deviceTile.modelData.batteryPercent * 3.6 : 0

                                Behavior on sweepAngle {
                                    NumberAnimation {
                                        duration: 300
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.deviceIcon(deviceTile.modelData.icon)
                        color: root.themeFg
                        font {
                            family: root.barFont
                            pixelSize: 26
                        }
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: deviceTile.batteryKnown ? deviceTile.modelData.batteryPercent + "%" : "unavailable"
                    color: deviceTile.batteryKnown ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, root.mutedOpacity)
                    font {
                        family: root.barFont
                        pixelSize: deviceTile.batteryKnown ? 14 : 11
                        weight: Font.Medium
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: deviceTile.modelData.name
                    color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, root.labelOpacity)
                    elide: Text.ElideRight
                    font {
                        family: root.barFont
                        pixelSize: 11
                    }
                }
            }
        }
    }
}
