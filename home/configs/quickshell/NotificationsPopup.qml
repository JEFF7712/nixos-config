import QtQuick
import Quickshell
import Quickshell.Io

InfoPopup {
    id: root
    title: "NOTIFICATIONS"

    property var allNotifications: []
    property var dismissedIds: ({})

    readonly property var filteredNotifications:
        root.allNotifications.filter(n => !root.dismissedIds[n.id])

    readonly property var notifications: root.filteredNotifications.slice(0, 8)
    readonly property int unreadCount: root.filteredNotifications.length

    function dismiss(id) {
        const next = Object.assign({}, root.dismissedIds)
        next[id] = true
        root.dismissedIds = next
        Quickshell.execDetached(["sh", "-c", "makoctl dismiss -n " + id + " --no-history 2>/dev/null"])
    }

    Repeater {
        model: root.notifications

        delegate: Item {
            id: notifItem
            width: parent.width
            height: textCol.implicitHeight + 14

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: root.pillBg
                border.width: 1
                border.color: root.pillBorder
            }

            Column {
                id: textCol
                anchors.left: parent.left
                anchors.right: closeBtn.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 4
                spacing: 2

                Text {
                    width: parent.width
                    text: (modelData.app || "system").toUpperCase()
                    color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.5)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 8
                        letterSpacing: 1.0
                        weight: Font.Medium
                    }
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: modelData.summary || ""
                    color: root.themeFg
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 10
                        weight: Font.Medium
                    }
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }

            Item {
                id: closeBtn
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 6
                anchors.topMargin: 4
                width: 18
                height: 18

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: closeMouse.containsMouse
                        ? root.themeFg
                        : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.6)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 16
                        weight: Font.Medium
                    }
                    Behavior on color { ColorAnimation { duration: 160 } }
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismiss(modelData.id)
                }
            }
        }
    }

    Text {
        width: parent.width
        text: "no notifications"
        visible: root.notifications.length === 0
        color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.4)
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; italic: true }
        horizontalAlignment: Text.AlignHCenter
        topPadding: 8
        bottomPadding: 8
    }

    Process {
        id: fetchProc
        command: ["sh", "-c", "makoctl history 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const notifs = []
                let current = null
                for (const raw of lines) {
                    const m = raw.match(/^Notification (\d+): (.*)$/)
                    if (m) {
                        if (current) notifs.push(current)
                        current = { id: m[1], summary: m[2], app: "" }
                    } else if (current) {
                        const am = raw.match(/^\s+App name: (.*)$/)
                        if (am) current.app = am[1]
                    }
                }
                if (current) notifs.push(current)
                root.allNotifications = notifs
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
}
