import QtQuick
import Quickshell
import Quickshell.Io

InfoPopup {
    id: root
    title: "NOTIFICATIONS"

    property var allNotifications: []
    property var dismissedIds: ({})
    property color themeWarm: "#e6dcc6"

    readonly property var filteredNotifications:
        root.allNotifications.filter(n => !root.dismissedIds[n.id])

    readonly property var notifications: root.filteredNotifications.slice(0, 7)
    readonly property int unreadCount: root.filteredNotifications.length
    readonly property bool hasOverflow: root.filteredNotifications.length > root.notifications.length

    function displayApp(notification) {
        return notification.app || "system"
    }

    function displaySummary(notification) {
        return notification.summary || notification.body || "Notification"
    }

    function displayBody(notification) {
        return notification.body && notification.body !== notification.summary ? notification.body : ""
    }

    function urgencyColor(urgency) {
        if (urgency === "critical") return root.themeWarm
        if (urgency === "low") return Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.42)
        return root.themeAccent
    }

    function hasActions(notification) {
        return notification.actions && Object.keys(notification.actions).length > 0
    }

    function countLabel() {
        if (root.unreadCount === 0) return "no notifications"
        return root.unreadCount + " in history"
    }

    function countColor() {
        if (root.unreadCount === 0) return Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.48)
        return root.themeFg
    }

    function rowBackgroundColor(pressed, hovered) {
        if (pressed) return Qt.rgba(1, 1, 1, 0.08)
        if (hovered) return Qt.rgba(1, 1, 1, 0.05)
        return "transparent"
    }

    function footerText() {
        if (root.notifications.length === 0) return "history is empty"
        if (root.hasOverflow) return "+" + (root.filteredNotifications.length - root.notifications.length) + " more"
        return ""
    }

    function dismiss(id) {
        const next = Object.assign({}, root.dismissedIds)
        next[id] = true
        root.dismissedIds = next
        Quickshell.execDetached(["sh", "-c", "makoctl dismiss -n " + id + " --no-history 2>/dev/null"])
    }

    function clearShown() {
        const next = Object.assign({}, root.dismissedIds)
        for (const notification of root.filteredNotifications) {
            next[notification.id] = true
        }
        root.dismissedIds = next
        Quickshell.execDetached(["sh", "-c", "makoctl dismiss -a --no-history 2>/dev/null"])
    }

    function restoreLatest() {
        Quickshell.execDetached(["sh", "-c", "makoctl restore 2>/dev/null"])
        fetchProc.running = true
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

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            NotificationButton {
                label: "restore"
                visible: root.unreadCount === 0
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                onActivated: root.restoreLatest()
            }

            NotificationButton {
                label: "clear"
                visible: root.unreadCount > 0
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                onActivated: root.clearShown()
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    Repeater {
        model: root.notifications

        delegate: Item {
            id: notifItem
            width: parent.width
            height: Math.max(42, textCol.implicitHeight + 12)

            readonly property color accentColor: root.urgencyColor(modelData.urgency)

            Rectangle {
                anchors.fill: parent
                radius: root.flatMode ? 0 : 6
                color: root.rowBackgroundColor(rowMouse.pressed, rowMouse.containsMouse)
                Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: parent.height - 14
                radius: 1
                color: notifItem.accentColor
                opacity: modelData.urgency === "normal" ? 0.0 : 0.75
            }

            Column {
                id: textCol
                anchors.left: parent.left
                anchors.right: closeBtn.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 2

                Row {
                    width: parent.width
                    spacing: 6

                    Text {
                        width: parent.width - metaText.implicitWidth - 6
                        text: root.displaySummary(modelData)
                        color: root.themeFg
                        font {
                            family: "JetBrainsMono Nerd Font"
                            pixelSize: 10
                            weight: Font.Medium
                        }
                        wrapMode: Text.WordWrap
                        maximumLineCount: root.displayBody(modelData) === "" ? 2 : 1
                        elide: Text.ElideRight
                    }

                    Text {
                        id: metaText
                        text: root.displayApp(modelData).toUpperCase()
                        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.42)
                        font {
                            family: "JetBrainsMono Nerd Font"
                            pixelSize: 8
                            weight: Font.Medium
                        }
                        elide: Text.ElideRight
                    }
                }

                Text {
                    width: parent.width
                    text: root.displayBody(modelData)
                    visible: text !== ""
                    color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.56)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 9
                    }
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
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
                    color: closeMouse.containsMouse
                        ? root.themeFg
                        : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.45)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 14
                        weight: Font.Medium
                    }
                    Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismiss(modelData.id)
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                anchors.rightMargin: 24
                hoverEnabled: true
                cursorShape: root.hasActions(modelData) ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.hasActions(modelData)) {
                        Quickshell.execDetached(["sh", "-c", "makoctl invoke -n " + modelData.id + " 2>/dev/null"])
                        root.dismiss(modelData.id)
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        text: root.footerText()
        visible: text !== ""
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.36)
        font {
            family: "JetBrainsMono Nerd Font"
            pixelSize: 9
            italic: root.notifications.length === 0
        }
        horizontalAlignment: Text.AlignHCenter
        topPadding: root.notifications.length === 0 ? 8 : 2
        bottomPadding: root.notifications.length === 0 ? 8 : 0
    }

    Process {
        id: fetchProc
        command: ["sh", "-c", "makoctl history -j 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text || "[]")
                    root.allNotifications = parsed.map(n => ({
                        id: String(n.id),
                        app: n.app_name || n.desktop_entry || "",
                        summary: n.summary || "",
                        body: n.body || "",
                        urgency: n.urgency || "normal",
                        actions: n.actions || {}
                    }))
                } catch (e) {
                    root.allNotifications = []
                }
            }
        }
    }

    onShownChanged: { if (shown) fetchProc.running = true }

    Timer {
        running: true
        interval: root.shown ? 5000 : 15000
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }

    component NotificationButton: Item {
        id: buttonRoot
        property string label: ""
        property color themeFg: "#ffffff"
        property color themeAccent: "#ffffff"
        signal activated()

        width: buttonText.implicitWidth + 10
        height: 20

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: buttonRoot.label
            color: buttonMouse.containsMouse
                ? buttonRoot.themeAccent
                : Qt.rgba(buttonRoot.themeFg.r, buttonRoot.themeFg.g, buttonRoot.themeFg.b, 0.55)
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 9
                weight: Font.Medium
            }
            Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
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
