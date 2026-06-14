import QtQuick

InfoPopup {
    id: root
    title: "CALENDAR"
    popupPosition: "center"

    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    readonly property var monthNames: [
        "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
        "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
    ]
    readonly property var dayLabels: ["S", "M", "T", "W", "T", "F", "S"]

    function shift(delta) {
        let y = root.viewYear
        let m = root.viewMonth + delta
        while (m < 0) { m += 12; y -= 1 }
        while (m > 11) { m -= 12; y += 1 }
        root.viewYear = y
        root.viewMonth = m
    }

    function gridDays() {
        const first = new Date(root.viewYear, root.viewMonth, 1)
        const startDow = first.getDay()
        const daysInMonth = new Date(root.viewYear, root.viewMonth + 1, 0).getDate()
        const cells = []
        for (let i = 0; i < startDow; i++) cells.push({ day: 0, current: false })
        for (let d = 1; d <= daysInMonth; d++) cells.push({ day: d, current: true })
        while (cells.length % 7 !== 0) cells.push({ day: 0, current: false })
        while (cells.length < 42) cells.push({ day: 0, current: false })
        return cells
    }

    Timer {
        running: root.shown
        interval: 60000
        repeat: true
        onTriggered: root.today = new Date()
    }

    Item {
        width: parent.width
        height: 26

        Text {
            id: leftBtn
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "‹"
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.7)
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: root.shift(-1)
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.monthNames[root.viewMonth] + " " + root.viewYear
            color: root.themeFg
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 11
                letterSpacing: 1.2
                weight: Font.Medium
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.7)
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: root.shift(1)
            }
        }
    }

    Grid {
        width: parent.width
        columns: 7
        rowSpacing: 2
        columnSpacing: 0

        Repeater {
            model: root.dayLabels
            delegate: Item {
                width: parent.width / 7
                height: 20
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.4)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 9
                        letterSpacing: 1
                        weight: Font.Medium
                    }
                }
            }
        }

        Repeater {
            model: root.gridDays()
            delegate: Item {
                width: parent.width / 7
                height: 26

                readonly property bool isToday:
                    modelData.current
                    && modelData.day === root.today.getDate()
                    && root.viewMonth === root.today.getMonth()
                    && root.viewYear === root.today.getFullYear()

                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: parent.isToday ? root.themeAccent : "transparent"
                    visible: modelData.current
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.day || ""
                    color: parent.isToday
                        ? root.themeRawBg
                        : modelData.current
                            ? root.themeFg
                            : Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.18)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 10
                        weight: parent.isToday ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }
}
