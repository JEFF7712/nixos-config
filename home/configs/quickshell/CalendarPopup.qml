import QtQuick

InfoPopup {
    id: root
    title: "CALENDAR"
    popupPosition: "left"
    edgeSlide: true

    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property int selectedYear: today.getFullYear()
    property int selectedMonth: today.getMonth()
    property int selectedDay: today.getDate()

    readonly property int cellSize: 32
    readonly property var monthNames: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
    readonly property var dayLabels: ["S", "M", "T", "W", "T", "F", "S"]

    function clampMonth(year, month) {
        let y = year;
        let m = month;
        while (m < 0) {
            m += 12;
            y -= 1;
        }
        while (m > 11) {
            m -= 12;
            y += 1;
        }
        return {
            year: y,
            month: m
        };
    }

    function shift(delta) {
        const next = root.clampMonth(root.viewYear, root.viewMonth + delta);
        root.viewYear = next.year;
        root.viewMonth = next.month;
    }

    function showToday() {
        root.today = new Date();
        root.viewYear = root.today.getFullYear();
        root.viewMonth = root.today.getMonth();
        root.selectedYear = root.viewYear;
        root.selectedMonth = root.viewMonth;
        root.selectedDay = root.today.getDate();
    }

    function selectCell(cell) {
        root.selectedYear = cell.year;
        root.selectedMonth = cell.month;
        root.selectedDay = cell.day;
        root.viewYear = cell.year;
        root.viewMonth = cell.month;
    }

    function isSameDay(year, month, day, date) {
        return day === date.getDate() && month === date.getMonth() && year === date.getFullYear();
    }

    function selectedDate() {
        return new Date(root.selectedYear, root.selectedMonth, root.selectedDay);
    }

    function selectedLabel() {
        const selected = root.selectedDate();
        const todayStart = new Date(root.today.getFullYear(), root.today.getMonth(), root.today.getDate());
        const deltaDays = Math.round((selected - todayStart) / 86400000);
        if (deltaDays === 0)
            return "TODAY";
        if (deltaDays === -1)
            return "YESTERDAY";
        if (deltaDays === 1)
            return "TOMORROW";
        return (deltaDays > 0 ? "+" : "") + deltaDays + " DAYS";
    }

    function weekNumber(date) {
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        const dayNum = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - dayNum);
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    }

    function gridDays() {
        const first = new Date(root.viewYear, root.viewMonth, 1);
        const startDow = first.getDay();
        const cells = [];

        for (let week = 0; week < 6; week++) {
            const weekStart = new Date(root.viewYear, root.viewMonth, week * 7 - startDow + 1);
            cells.push({
                kind: "week",
                week: root.weekNumber(weekStart)
            });

            for (let day = 0; day < 7; day++) {
                const date = new Date(root.viewYear, root.viewMonth, week * 7 + day - startDow + 1);
                cells.push({
                    kind: "day",
                    day: date.getDate(),
                    month: date.getMonth(),
                    year: date.getFullYear(),
                    current: date.getMonth() === root.viewMonth,
                    weekend: date.getDay() === 0 || date.getDay() === 6
                });
            }
        }

        return cells;
    }

    function dayBackgroundColor(isToday, isSelected, pressed, hovered) {
        if (isToday)
            return root.themeAccent;
        if (isSelected)
            return Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.28);
        if (pressed)
            return Qt.rgba(1, 1, 1, 0.12);
        if (hovered)
            return Qt.rgba(1, 1, 1, 0.07);
        return "transparent";
    }

    function dayTextColor(cell, isToday) {
        if (isToday)
            return root.themeRawBg;
        if (!cell.current)
            return Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.22);
        if (cell.weekend)
            return Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.72);
        return root.themeFg;
    }

    Timer {
        running: root.shown
        interval: 60000
        repeat: true
        onTriggered: root.today = new Date()
    }

    Item {
        width: parent.width
        height: 58

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: root.monthNames[root.viewMonth]
                color: root.themeFg
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 17
                    weight: Font.Light
                }
            }

            Text {
                text: root.viewYear + "  •  " + Qt.formatDate(root.today, "dddd, MMM d").toUpperCase()
                color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.48)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 9
                    weight: Font.Medium
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            CalendarButton {
                label: "‹"
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                flatMode: root.flatMode
                pillBg: root.pillBg
                pillBorder: root.pillBorder
                onActivated: root.shift(-1)
            }

            CalendarButton {
                label: "NOW"
                wide: true
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                flatMode: root.flatMode
                pillBg: root.pillBg
                pillBorder: root.pillBorder
                active: root.viewYear === root.today.getFullYear() && root.viewMonth === root.today.getMonth()
                onActivated: root.showToday()
            }

            CalendarButton {
                label: "›"
                themeFg: root.themeFg
                themeAccent: root.themeAccent
                flatMode: root.flatMode
                pillBg: root.pillBg
                pillBorder: root.pillBorder
                onActivated: root.shift(1)
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    Grid {
        width: parent.width
        columns: 8
        rowSpacing: 3
        columnSpacing: 1

        Item {
            width: 22
            height: 20
            Text {
                anchors.centerIn: parent
                text: "#"
                color: Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.38)
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 8
                    weight: Font.Bold
                }
            }
        }

        Repeater {
            model: root.dayLabels
            delegate: Item {
                width: root.cellSize
                height: 20
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: Qt.rgba(root.themeFg.r, root.themeFg.g, root.themeFg.b, 0.45)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 9
                        weight: Font.Medium
                    }
                }
            }
        }

        Repeater {
            model: root.gridDays()
            delegate: Item {
                width: modelData.kind === "week" ? 22 : root.cellSize
                height: 30

                readonly property bool isToday: modelData.kind === "day" && root.isSameDay(modelData.year, modelData.month, modelData.day, root.today)
                readonly property bool isSelected: modelData.kind === "day" && modelData.day === root.selectedDay && modelData.month === root.selectedMonth && modelData.year === root.selectedYear

                Text {
                    anchors.centerIn: parent
                    visible: modelData.kind === "week"
                    text: modelData.kind === "week" ? modelData.week : ""
                    color: Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.42)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 8
                        weight: Font.Medium
                    }
                }

                Rectangle {
                    id: dayBg
                    anchors.centerIn: parent
                    visible: modelData.kind === "day"
                    width: 26
                    height: 26
                    radius: root.flatMode ? 5 : 9
                    color: root.dayBackgroundColor(parent.isToday, parent.isSelected, dayMouse.pressed, dayMouse.containsMouse)
                    border.width: parent.isToday || parent.isSelected || dayMouse.containsMouse ? 1 : 0
                    border.color: parent.isToday ? root.themeAccent : Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.34)
                    scale: dayMouse.pressed ? 0.92 : (dayMouse.containsMouse ? 1.05 : 1.0)

                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        SpringAnimation {
                            spring: 4
                            damping: 0.58
                            mass: 0.7
                        }
                    }
                }

                Text {
                    anchors.centerIn: dayBg
                    visible: modelData.kind === "day"
                    text: modelData.day || ""
                    color: root.dayTextColor(modelData, parent.isToday)
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 10
                        weight: parent.isToday || parent.isSelected ? Font.Bold : Font.Medium
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    id: dayMouse
                    anchors.fill: dayBg
                    hoverEnabled: modelData.kind === "day"
                    cursorShape: modelData.kind === "day" ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (modelData.kind === "day")
                            root.selectCell(modelData);
                    }
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: root.dividerColor
    }

    Item {
        width: parent.width
        height: 26

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDate(root.selectedDate(), "ddd d MMM yyyy").toUpperCase()
            color: root.themeFg
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 10
                weight: Font.Medium
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: statusText.implicitWidth + 16
            height: 20
            radius: root.flatMode ? 4 : 7
            color: Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.12)
            border.width: 1
            border.color: Qt.rgba(root.themeAccent.r, root.themeAccent.g, root.themeAccent.b, 0.2)

            Text {
                id: statusText
                anchors.centerIn: parent
                text: root.selectedLabel()
                color: root.themeAccent
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 8
                    weight: Font.Bold
                }
            }
        }
    }

    component CalendarButton: Item {
        id: buttonRoot
        property string label: ""
        property bool active: false
        property bool wide: false
        property bool flatMode: false
        property color themeFg: "#ffffff"
        property color themeAccent: "#ffffff"
        property color pillBg: Qt.rgba(1, 1, 1, 0.05)
        property color pillBorder: Qt.rgba(1, 1, 1, 0.1)
        signal activated

        width: wide ? 42 : 28
        height: 28

        function backgroundColor() {
            if (buttonRoot.active) {
                return Qt.rgba(buttonRoot.themeAccent.r, buttonRoot.themeAccent.g, buttonRoot.themeAccent.b, 0.18);
            }
            if (buttonMouse.pressed)
                return Qt.rgba(1, 1, 1, 0.12);
            if (buttonMouse.containsMouse)
                return Qt.rgba(1, 1, 1, 0.07);
            return buttonRoot.pillBg;
        }

        Rectangle {
            anchors.fill: parent
            radius: buttonRoot.flatMode ? 5 : 8
            color: buttonRoot.backgroundColor()
            border.width: 1
            border.color: buttonRoot.active || buttonMouse.containsMouse ? Qt.rgba(buttonRoot.themeAccent.r, buttonRoot.themeAccent.g, buttonRoot.themeAccent.b, 0.36) : buttonRoot.pillBorder
            Behavior on color {
                ColorAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: buttonRoot.label
            color: buttonRoot.active ? buttonRoot.themeAccent : buttonRoot.themeFg
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: buttonRoot.wide ? 9 : 15
                weight: Font.Bold
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
