import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."

PanelWindow {
    id: root

    property bool shown: false
    signal close()

    visible: shown
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    focusable: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "bar-popup"

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: 48
        width: 220; height: 200
        radius: 12
        color: Theme.withAlpha(Theme.surface, 0.97)
        border.color: Theme.withAlpha(Theme.border, 0.35); border.width: 1

        MouseArea { anchors.fill: parent }

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
                    text: "\u2039"; color: Theme.accent; font.pixelSize: 18
                    font.family: "JetBrainsMono Nerd Font"
                    MouseArea { anchors.fill: parent; onClicked: card.displayMonth = new Date(card.displayMonth.getFullYear(), card.displayMonth.getMonth()-1, 1) }
                }
                Text {
                    Layout.fillWidth: true
                    text: card.monthNames[card.displayMonth.getMonth()] + " " + card.displayMonth.getFullYear()
                    color: Theme.text; font.pixelSize: 12; font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: "\u203a"; color: Theme.accent; font.pixelSize: 18
                    font.family: "JetBrainsMono Nerd Font"
                    MouseArea { anchors.fill: parent; onClicked: card.displayMonth = new Date(card.displayMonth.getFullYear(), card.displayMonth.getMonth()+1, 1) }
                }
            }

            Grid {
                columns: 7; spacing: 2; width: parent.width
                property var dayNames: ["Su","Mo","Tu","We","Th","Fr","Sa"]
                Repeater {
                    model: parent.dayNames
                    Text {
                        width: 26; text: modelData; color: Theme.textSubtle
                        font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Grid {
                id: dayGrid
                columns: 7; spacing: 2; width: parent.width
                property int offset: card.firstDayOfMonth(card.displayMonth)
                property int days:   card.daysInMonth(card.displayMonth)
                property int today:  new Date().getDate()
                property bool isCurrentMonth:
                    card.displayMonth.getFullYear() === new Date().getFullYear() &&
                    card.displayMonth.getMonth()    === new Date().getMonth()

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
                            font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                        }
                    }
                }
            }
        }
    }
}
