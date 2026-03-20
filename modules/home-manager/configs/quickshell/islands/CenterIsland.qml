import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    implicitHeight: 28
    radius: 14
    color: Theme.withAlpha(Theme.surface, 0.85)
    border.color: Theme.withAlpha(Theme.border, 0.3)
    border.width: 1
    implicitWidth: col.implicitWidth + 32

    signal calendarRequested()

    function updateTime() {
        const now = new Date()
        timeText.text = now.toLocaleTimeString(Qt.locale(), "hh:mm")
        dateText.text = now.toLocaleDateString(Qt.locale(), "ddd, MMM d")
    }

    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.updateTime()
    }

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 0

        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            text: "00:00"
            color: Theme.text
            font.pixelSize: 13; font.bold: true
            font.family: "JetBrainsMono Nerd Font"
        }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            text: ""
            color: Theme.textSubtle
            font.pixelSize: 9
            font.family: "JetBrainsMono Nerd Font"
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.calendarRequested()
    }
}
