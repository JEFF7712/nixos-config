import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    signal closeRequested()

    width: 220; height: 200; radius: 12
    color: Theme.surfaceVariant
    border.color: Theme.border; border.width: 1
    y: 36; x: -90

    property date displayMonth: new Date()

    readonly property var monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]

    function firstDayOfMonth(d) {
        return new Date(d.getFullYear(), d.getMonth(), 1).getDay()
    }
    function daysInMonth(d) {
        return new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
    }

    Column {
        anchors { fill: parent; margins: 10 }
        spacing: 6

        RowLayout {
            width: parent.width
            Text {
                text: "‹"; color: Theme.accent; font.pixelSize: 16
                MouseArea { anchors.fill: parent; onClicked: root.displayMonth = new Date(root.displayMonth.getFullYear(), root.displayMonth.getMonth()-1, 1) }
            }
            Text {
                Layout.fillWidth: true
                text: root.monthNames[root.displayMonth.getMonth()] + " " + root.displayMonth.getFullYear()
                color: Theme.text; font.pixelSize: 12; font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                text: "›"; color: Theme.accent; font.pixelSize: 16
                MouseArea { anchors.fill: parent; onClicked: root.displayMonth = new Date(root.displayMonth.getFullYear(), root.displayMonth.getMonth()+1, 1) }
            }
        }

        Grid {
            columns: 7; spacing: 2; width: parent.width
            property var dayNames: ["Su","Mo","Tu","We","Th","Fr","Sa"]
            Repeater {
                model: parent.dayNames
                Text { width: 26; text: modelData; color: Theme.textSubtle; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter }
            }
        }

        Grid {
            id: dayGrid
            columns: 7; spacing: 2; width: parent.width
            property int offset: root.firstDayOfMonth(root.displayMonth)
            property int days:   root.daysInMonth(root.displayMonth)
            property int today:  new Date().getDate()
            property bool isCurrentMonth:
                root.displayMonth.getFullYear() === new Date().getFullYear() &&
                root.displayMonth.getMonth()    === new Date().getMonth()

            Repeater {
                model: dayGrid.offset + dayGrid.days
                delegate: Rectangle {
                    required property int index
                    width: 26; height: 22; radius: 6
                    property int day: index - dayGrid.offset + 1
                    property bool valid: index >= dayGrid.offset
                    property bool isToday: valid && dayGrid.isCurrentMonth && day === dayGrid.today
                    color: isToday ? Theme.accent : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: parent.valid ? parent.day : ""
                        color: parent.isToday ? Theme.accentText : Theme.text
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    MouseArea {
        parent: root.parent; anchors.fill: parent; z: -1
        onClicked: root.closeRequested()
    }
}
