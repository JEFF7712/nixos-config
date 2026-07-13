import QtQuick
import Quickshell
import "services" as Services

InfoPopup {
    id: root
    title: "SYSTEM"
    edgeSlide: true

    required property Services.SystemService systemService
    property color themeWarm: "#e6dcc6"

    readonly property string hostName: systemService.hostName !== "" ? systemService.hostName : "-"
    readonly property string kernel: systemService.kernel !== "" ? systemService.kernel : "-"
    readonly property string uptime: systemService.uptime !== "" ? systemService.uptime : "-"
    readonly property string cpuUsage: systemService.available ? systemService.cpuPercent + "%" : "-"
    readonly property string ramUsage: systemService.available ? systemService.ramUsedGiB.toFixed(1) + "G" : "-"
    readonly property string diskUsage: systemService.available ? systemService.diskPercent + "%" : "-"
    readonly property int ramPercent: systemService.available ? systemService.ramPercent : 0

    function exec(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
        root.close();
    }

    function percent(value) {
        const parsed = parseInt(String(value).replace("%", ""));
        return isNaN(parsed) ? 0 : Math.max(0, Math.min(100, parsed));
    }

    function systemMeta() {
        const parts = [];
        if (root.kernel !== "-")
            parts.push(root.kernel);
        if (root.systemService.nixGeneration !== "")
            parts.push("gen " + root.systemService.nixGeneration);
        return parts.join("  ");
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
                text: root.hostName
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
                text: root.systemMeta()
                color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.44)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 9
                }
                elide: Text.ElideRight
            }
        }
    }

    InfoRow {
        label: "uptime"
        value: root.uptime
        themeFg: root.themeFg
        active: root.shown
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    ResourceRow {
        label: "cpu"
        value: root.cpuUsage
        amount: root.percent(root.cpuUsage)
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        pillBg: root.pillBg
    }

    ResourceRow {
        label: "ram"
        value: root.ramUsage
        amount: root.ramPercent
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        pillBg: root.pillBg
    }

    ResourceRow {
        label: "disk"
        value: root.diskUsage
        amount: root.percent(root.diskUsage)
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        pillBg: root.pillBg
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    SystemAction {
        icon: "󰌾"
        label: "lock"
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        onActivated: {
            root.systemService.lock();
            root.close();
        }
    }

    SystemAction {
        icon: "󰒲"
        label: "sleep"
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        onActivated: {
            root.systemService.suspend();
            root.close();
        }
    }

    SystemAction {
        icon: "󰍃"
        label: "logout"
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        onActivated: root.exec("niri msg action quit -s")
    }

    SystemAction {
        icon: "󰜉"
        label: "restart"
        warm: true
        themeFg: root.themeFg
        themeAccent: root.themeWarm
        onActivated: {
            root.systemService.reboot();
            root.close();
        }
    }

    SystemAction {
        icon: "󰐥"
        label: "shutdown"
        warm: true
        themeFg: root.themeFg
        themeAccent: root.themeWarm
        onActivated: {
            root.systemService.powerOff();
            root.close();
        }
    }

    component ResourceRow: Item {
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

    component SystemAction: Item {
        id: actionRoot
        property string icon: ""
        property string label: ""
        property bool warm: false
        property color themeFg: "#ffffff"
        property color themeAccent: "#ffffff"
        signal activated

        width: parent.width
        height: 26

        Rectangle {
            anchors.fill: parent
            radius: root.flatMode ? 0 : 6
            color: actionMouse.pressed ? Qt.rgba(1, 1, 1, 0.08) : actionMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }

        Text {
            id: iconText
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: actionRoot.icon
            color: actionRoot.warm ? actionRoot.themeAccent : Qt.rgba(actionRoot.themeFg.r, actionRoot.themeFg.g, actionRoot.themeFg.b, 0.68)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 12
            }
        }

        Text {
            anchors.left: iconText.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: actionRoot.label
            color: actionRoot.warm ? actionRoot.themeAccent : Qt.rgba(actionRoot.themeFg.r, actionRoot.themeFg.g, actionRoot.themeFg.b, 0.86)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 11
                weight: actionRoot.warm ? Font.Medium : Font.Normal
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionRoot.activated()
        }
    }
}
