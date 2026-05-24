import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool shown: false
    property string query: ""
    property int focusedIndex: 0
    property string activeProfile: ""

    readonly property var profileAccents: ({
        "noctalia":   "#b1c6ff",
        "clean":      "#eeeeee",
        "minimal":    "#e0e0e0",
        "nord":       "#88c0d0",
        "catppuccin": "#cba6f7",
        "gruvbox":    "#fabd2f",
        "rosepine":   "#c4a7e7",
        "everforest": "#a7c080"
    })
    readonly property color accent: profileAccents[activeProfile] || "#ffffff"

    readonly property int columns: 6
    readonly property int visibleRows: 3
    readonly property int tileWidth: 140
    readonly property int tileHeight: 130
    readonly property int tileSpacing: 8

    readonly property var allEntries: (DesktopEntries.applications.values || [])
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property var entries: {
        const q = query.toLowerCase().trim()
        return q.length > 0
            ? allEntries.filter(e => e.name.toLowerCase().includes(q))
            : allEntries
    }

    function open() {
        activeProc.running = true
        query = ""
        focusedIndex = 0
        shown = true
    }
    function close() { shown = false }
    function toggle() { if (shown) close(); else open() }

    function launch(entry) {
        if (entry) entry.execute()
        close()
    }

    function moveFocus(dx, dy) {
        const n = entries.length
        if (n === 0) return
        const cur = Math.max(0, Math.min(n - 1, focusedIndex))
        let r = Math.floor(cur / columns)
        let c = cur % columns
        c = Math.max(0, Math.min(columns - 1, c + dx))
        r = Math.max(0, r + dy)
        let next = r * columns + c
        if (next >= n) next = n - 1
        focusedIndex = next
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function show(): void { root.open() }
        function hide(): void { root.close() }
    }

    WlrLayershell.namespace: "quickshell-app-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int gridWidth: columns * (tileWidth + tileSpacing)
    readonly property int gridHeight: visibleRows * (tileHeight + tileSpacing)
    readonly property int searchBarHeight: 38
    readonly property int columnGap: 14
    readonly property int cardPadding: 36

    visible: shown
    exclusiveZone: -1
    color: "transparent"
    implicitWidth: root.gridWidth + cardPadding
    implicitHeight: root.searchBarHeight + root.columnGap + root.gridHeight + cardPadding

    Process {
        id: activeProc
        command: ["sh", "-c", "cat \"$HOME\"/.config/desktop-profiles/active 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: { root.activeProfile = text.trim() }
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(0.13, 0.13, 0.13, 0.875)
        border.width: 1
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28)
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.96
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.55; mass: 0.7 } }

        MouseArea { anchors.fill: parent }

        Column {
            id: contentColumn
            anchors.centerIn: parent
            spacing: 14
            width: root.gridWidth

            Rectangle {
                id: searchBar
                width: parent.width
                height: 38
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: queryInput.activeFocus
                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
                    : Qt.rgba(1, 1, 1, 0.10)
                Behavior on border.color { ColorAnimation { duration: 140 } }

                TextInput {
                    id: queryInput
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: "white"
                    selectionColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
                    selectedTextColor: "white"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    text: root.query
                    focus: root.shown
                    onTextChanged: {
                        root.query = text
                        root.focusedIndex = 0
                    }
                    cursorDelegate: Rectangle {
                        visible: queryInput.cursorVisible
                        color: root.accent
                        width: 2
                    }

                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: root.launch(root.entries[root.focusedIndex])
                    Keys.onEnterPressed: root.launch(root.entries[root.focusedIndex])
                    Keys.onLeftPressed: (event) => {
                        if (text.length === 0 || cursorPosition === 0) {
                            root.moveFocus(-1, 0)
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    }
                    Keys.onRightPressed: (event) => {
                        if (text.length === 0 || cursorPosition === text.length) {
                            root.moveFocus(1, 0)
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    }
                    Keys.onUpPressed: root.moveFocus(0, -1)
                    Keys.onDownPressed: root.moveFocus(0, 1)
                    Keys.onTabPressed: root.moveFocus(1, 0)
                    Keys.onBacktabPressed: root.moveFocus(-1, 0)

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Search…"
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font: queryInput.font
                        visible: queryInput.text.length === 0
                    }
                }
            }

            Item {
                width: root.gridWidth
                height: root.gridHeight

                Text {
                    anchors.centerIn: parent
                    text: "no matches"
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.italic: true
                    visible: root.entries.length === 0 && root.query.length > 0
                }

                GridView {
                    id: gridView
                    anchors.fill: parent
                    cellWidth: root.tileWidth + root.tileSpacing
                    cellHeight: root.tileHeight + root.tileSpacing
                    clip: true
                    model: root.entries
                    visible: root.entries.length > 0
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 4000

                    currentIndex: root.focusedIndex
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                    delegate: Item {
                        id: tile
                        width: gridView.cellWidth
                        height: gridView.cellHeight

                        property bool hovered: tileMouse.containsMouse
                        property bool isFocused: index === root.focusedIndex

                        Rectangle {
                            anchors.centerIn: parent
                            width: root.tileWidth
                            height: root.tileHeight
                            radius: 10
                            color: tile.isFocused ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                            border.width: 1
                            border.color: tile.hovered || tile.isFocused
                                ? root.accent
                                : Qt.rgba(1, 1, 1, 0.06)
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 14
                                width: 56
                                height: 56
                                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                sourceSize.width: 112
                                sourceSize.height: 112
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 10
                                width: parent.width - 12
                                text: modelData.name
                                color: "white"
                                opacity: tile.hovered || tile.isFocused ? 1.0 : 0.78
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.focusedIndex = index
                            onClicked: root.launch(modelData)
                        }
                    }
                }
            }
        }
    }
}
