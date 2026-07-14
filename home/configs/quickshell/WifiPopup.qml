import QtQuick
import "services" as Services

InfoPopup {
    id: root
    title: "NETWORK"

    required property Services.NetworkService networkService

    function signalIcon(signal) {
        if (signal > 75)
            return "󰤨";
        if (signal > 50)
            return "󰤥";
        if (signal > 25)
            return "󰤢";
        return "󰤟";
    }

    function networkMeta(network) {
        const parts = [];
        if (network.secure)
            parts.push(network.security);
        else
            parts.push("open");
        if (network.known)
            parts.push("known");
        parts.push(network.signal + "%");
        return parts.join("  ");
    }

    function statusLabel() {
        if (!root.networkService.wifiEnabled)
            return "wifi disabled";
        if (root.networkService.activeSsid)
            return root.networkService.activeSsid;
        return "not connected";
    }

    function statusMeta() {
        if (!root.networkService.wifiEnabled)
            return "radio off";
        if (root.networkService.activeSsid) {
            const sec = root.networkService.activeSecurity || "open";
            return sec + "  " + root.networkService.activeSignal + "%";
        }
        if (root.networkService.networks.count > 0)
            return root.networkService.networks.count + " networks visible";
        return "no networks visible";
    }

    Item {
        width: parent.width
        height: 26

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.statusLabel()
            color: root.networkService.wifiEnabled ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.48)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 11
                weight: Font.Medium
            }
            elide: Text.ElideRight
            width: parent.width - toggleRow.width - 10
        }

        Row {
            id: toggleRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            InfoToggle {
                width: 32
                label: ""
                checked: root.networkService.wifiEnabled
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                themeRawBg: root.themeRawBg
                dividerColor: root.dividerColor
                onToggled: root.networkService.setWifiEnabled(!root.networkService.wifiEnabled)
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
        visible: root.statusMeta() !== ""
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
        visible: root.networkService.wifiEnabled
    }

    Repeater {
        model: root.networkService.wifiEnabled ? root.networkService.networks : 0

        delegate: Item {
            id: networkRow
            width: parent.width
            height: 36

            readonly property bool activeNetwork: model.ssid === root.networkService.activeSsid

            Rectangle {
                anchors.fill: parent
                radius: root.flatMode ? 0 : 6
                color: rowMouse.pressed ? Qt.rgba(1, 1, 1, 0.08) : rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                id: signalText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 6
                text: root.signalIcon(model.signal)
                color: networkRow.activeNetwork ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.62)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 12
                }
            }

            Column {
                anchors.left: signalText.right
                anchors.right: stateText.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 1

                Text {
                    width: parent.width
                    text: model.ssid
                    color: networkRow.activeNetwork ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.88)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 10
                        weight: networkRow.activeNetwork ? Font.Medium : Font.Normal
                    }
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.networkMeta(model)
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
                text: model.busy ? "..." : (networkRow.activeNetwork ? "on" : "")
                color: networkRow.activeNetwork ? root.themeAccent : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.46)
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
                    if (networkRow.activeNetwork || model.busy)
                        return;
                    if (model.known) {
                        root.networkService.connectKnown(model.ssid);
                    } else {
                        root.networkService.connectInteractive(model.ssid);
                        root.close();
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        text: root.networkService.wifiEnabled ? "no networks visible" : "radio is off"
        visible: !root.networkService.wifiEnabled || root.networkService.networks.count === 0
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
