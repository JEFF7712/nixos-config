import QtQuick
import Quickshell

InfoPopup {
    id: root
    title: "NOTIFICATIONS"

    property color themeWarm: "#e6dcc6"
    property var expandedApps: ({})

    readonly property var historyList: NotifService.model.values
    readonly property int unreadCount: root.historyList.length

    readonly property var groups: {
        const list = NotifService.model.values;
        const map = {};
        const order = [];
        for (var i = list.length - 1; i >= 0; i--) {
            const n = list[i];
            const app = NotifService.appLabel(n);
            if (!map[app]) {
                map[app] = {
                    app: app,
                    icon: NotifService.iconSource(n),
                    items: []
                };
                order.push(app);
            }
            map[app].items.push(n);
        }
        return order.map(a => map[a]);
    }

    function urgencyColor(notification) {
        const u = NotifService.urgencyName(notification);
        if (u === "critical")
            return root.themeWarm;
        if (u === "low")
            return Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.42);
        return root.themeAccent;
    }

    function toggleApp(app) {
        const next = Object.assign({}, root.expandedApps);
        next[app] = !next[app];
        root.expandedApps = next;
    }

    function clearGroup(group) {
        for (const n of group.items.slice())
            NotifService.dismiss(n);
    }

    function countLabel() {
        if (root.unreadCount === 0)
            return "no notifications";
        return root.unreadCount + (root.unreadCount === 1 ? " notification" : " notifications");
    }

    function countColor() {
        if (root.unreadCount === 0)
            return Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.48);
        return root.themeFg;
    }

    Item {
        width: parent.width
        height: 26

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.countLabel()
            color: root.countColor()
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 11
                weight: Font.Medium
            }
        }

        NotificationButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            label: "clear all"
            visible: root.unreadCount > 0
            themeFg: root.themeFg
            themeAccent: root.themeAccent
            onActivated: NotifService.dismissAll()
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    Repeater {
        model: root.groups

        delegate: Column {
            id: groupItem
            required property var modelData

            readonly property bool expanded: root.expandedApps[modelData.app] === true
            readonly property var visibleItems: expanded ? modelData.items : modelData.items.slice(0, 1)

            width: parent.width
            spacing: 2

            Item {
                width: parent.width
                height: 28

                Image {
                    id: groupIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    sourceSize.width: 32
                    sourceSize.height: 32
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: status === Image.Ready
                    source: groupItem.modelData.icon
                }

                Text {
                    id: groupName
                    anchors.left: groupIcon.visible ? groupIcon.right : parent.left
                    anchors.leftMargin: groupIcon.visible ? 7 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: groupItem.modelData.app.toUpperCase()
                    color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.75)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 9
                        letterSpacing: 1.2
                        weight: Font.Medium
                    }
                }

                Rectangle {
                    anchors.left: groupName.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: badge.implicitWidth + 10
                    height: 15
                    radius: 7
                    color: root.pillBg
                    border.width: 1
                    border.color: root.pillBorder
                    visible: groupItem.modelData.items.length > 1

                    Text {
                        id: badge
                        anchors.centerIn: parent
                        text: groupItem.modelData.items.length
                        color: root.themeAccent
                        font {
                            family: "JetBrainsMono Nerd Font"
                            pixelSize: 8
                            weight: Font.Medium
                        }
                    }
                }

                NotificationButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    label: "clear"
                    themeFg: root.themeFg
                    themeAccent: root.themeAccent
                    onActivated: root.clearGroup(groupItem.modelData)
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: 40
                    cursorShape: groupItem.modelData.items.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (groupItem.modelData.items.length > 1)
                            root.toggleApp(groupItem.modelData.app);
                    }
                }
            }

            Repeater {
                model: groupItem.visibleItems

                delegate: Item {
                    id: notifItem
                    required property var modelData

                    width: groupItem.width
                    height: Math.max(36, textCol.implicitHeight + 10)

                    readonly property color accentColor: root.urgencyColor(modelData)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: parent.height - 12
                        radius: 1
                        color: notifItem.accentColor
                        opacity: NotifService.urgencyName(notifItem.modelData) === "normal" ? 0.0 : 0.7
                    }

                    Column {
                        id: textCol
                        anchors.left: parent.left
                        anchors.right: closeBtn.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 2

                        Text {
                            width: parent.width
                            text: notifItem.modelData.summary || notifItem.modelData.body || "Notification"
                            color: root.themeFg
                            font {
                                family: "JetBrainsMono Nerd Font"
                                pixelSize: 10
                                weight: Font.Medium
                            }
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: notifItem.modelData.body
                            visible: text !== "" && text !== notifItem.modelData.summary
                            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.56)
                            font {
                                family: "JetBrainsMono Nerd Font"
                                pixelSize: 9
                            }
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }

                    Item {
                        id: closeBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: closeMouse.containsMouse ? root.themeFg : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.45)
                            font {
                                family: "JetBrainsMono Nerd Font"
                                pixelSize: 14
                                weight: Font.Medium
                            }
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotifService.dismiss(notifItem.modelData)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 24
                        cursorShape: notifItem.modelData.actions.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            const acts = notifItem.modelData.actions;
                            if (acts.length > 0) {
                                acts[0].invoke();
                                NotifService.dismiss(notifItem.modelData);
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        text: "history is empty"
        visible: root.unreadCount === 0
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

    component NotificationButton: Item {
        id: buttonRoot
        property string label: ""
        property color themeFg: "#ffffff"
        property color themeAccent: "#ffffff"
        signal activated

        width: buttonText.implicitWidth + 10
        height: 20

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: buttonRoot.label
            color: buttonMouse.containsMouse ? buttonRoot.themeAccent : Qt.rgba(buttonRoot.themeFg.r, buttonRoot.themeFg.g, buttonRoot.themeFg.b, 0.55)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 9
                weight: Font.Medium
            }
            Behavior on color {
                ColorAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
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
