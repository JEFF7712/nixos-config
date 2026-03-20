import QtQuick
import QtQuick.Layouts
import ".."
import "../popups"

Rectangle {
    id: root
    height: 28
    radius: 14
    color: Qt.rgba(
        parseInt(Theme.surface.slice(1,3), 16) / 255,
        parseInt(Theme.surface.slice(3,5), 16) / 255,
        parseInt(Theme.surface.slice(5,7), 16) / 255,
        0.85
    )
    border.color: Qt.rgba(
        parseInt(Theme.border.slice(1,3), 16) / 255,
        parseInt(Theme.border.slice(3,5), 16) / 255,
        parseInt(Theme.border.slice(5,7), 16) / 255,
        0.2
    )
    border.width: 1
    implicitWidth: col.implicitWidth + 32

    // calendarVisible is wired to CalendarPopup in Task 18
    property bool calendarVisible: false

    function updateTime() {
        const now = new Date()
        timeText.text = now.toLocaleTimeString(Qt.locale(), "hh:mm")
        dateText.text = now.toLocaleDateString(Qt.locale(), "ddd, MMM d")
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
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
            font.pixelSize: 13
            font.bold: true
        }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            text: ""
            color: Theme.textSubtle
            font.pixelSize: 9
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.calendarVisible = !root.calendarVisible
    }

    CalendarPopup {
        visible: root.calendarVisible
        onCloseRequested: root.calendarVisible = false
    }
}
