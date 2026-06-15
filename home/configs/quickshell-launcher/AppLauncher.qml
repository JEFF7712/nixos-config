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

    property color accent: "#b1c6ff"
    property color cardBg: Qt.rgba(0.13, 0.13, 0.13, 0.875)
    property color textColor: "#ffffff"
    property color cardBorder: "#3dffffff"
    property color innerHighlight: "#0fffffff"
    property color pillBg: "#0affffff"
    property color pillBorder: "#14ffffff"
    property bool flatMode: false
    readonly property int cardRadius: flatMode ? 0 : 18
    readonly property int innerRadius: flatMode ? 0 : 10

    readonly property int columns: 6
    readonly property int visibleRows: 3
    readonly property int tileWidth: 72
    readonly property int tileHeight: 72
    readonly property int tileSpacing: 6

    readonly property var allEntries: (DesktopEntries.applications.values || [])
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property var entries: {
        const q = query.toLowerCase().trim()
        return q.length > 0
            ? allEntries.filter(e => e.name.toLowerCase().includes(q))
            : allEntries
    }

    function applyTheme(theme) {
        root.accent = theme && theme.accent ? theme.accent : "#b1c6ff"
        root.cardBg = theme && theme.popupBg ? theme.popupBg : Qt.rgba(0.13, 0.13, 0.13, 0.875)
        root.textColor = theme && theme.fg ? theme.fg : "#ffffff"
        root.flatMode = !!(theme && theme.flatMode === "true")
        root.cardBorder = theme && theme.barBorder ? theme.barBorder : "#3dffffff"
        root.innerHighlight = theme && theme.barInnerHighlight ? theme.barInnerHighlight : "#0fffffff"
        root.pillBg = theme && theme.pillBg ? theme.pillBg : "#0affffff"
        root.pillBorder = theme && theme.pillBorder ? theme.pillBorder : "#14ffffff"
    }

    function open() {
        themeLoader.running = true
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
    readonly property int searchBarHeight: 34
    readonly property int columnGap: 10
    readonly property int cardPadding: 28

    visible: shown
    exclusiveZone: -1
    color: "transparent"
    implicitWidth: root.gridWidth + cardPadding
    implicitHeight: root.searchBarHeight + root.columnGap + root.gridHeight + cardPadding

    Process {
        id: themeLoader
        running: true
        command: ["sh", "-c",
            "p=\"$HOME/.config/desktop-profiles\";" +
            "[ -f \"$p/active\" ] || exit 0;" +
            "d=\"$p/$(cat $p/active)\";" +
            "v=$(cat \"$p/active-variant\" 2>/dev/null || echo dark);" +
            "t=\"$d/quickshell-theme.json\";" +
            "if [ \"$v\" = light ] && [ -s \"$d/quickshell-theme-light.json\" ]; then t=\"$d/quickshell-theme-light.json\"; fi;" +
            "cat \"$t\" 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = this.text.trim()
                if (!txt) { root.applyTheme(null); return }
                try {
                    root.applyTheme(JSON.parse(txt))
                } catch (e) {
                    console.warn("quickshell-theme.json parse failed:", e)
                }
            }
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: root.cardRadius
        color: root.cardBg
        border.width: 1
        border.color: root.cardBorder
        opacity: root.shown ? 1.0 : 0.0
        scale: root.shown ? 1.0 : 0.96
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.55; mass: 0.7 } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            color: root.innerHighlight
        }

        MouseArea { anchors.fill: parent }

        Column {
            id: contentColumn
            anchors.centerIn: parent
            spacing: 14
            width: root.gridWidth

            Rectangle {
                id: searchBar
                width: parent.width
                height: root.searchBarHeight
                radius: root.innerRadius
                color: root.pillBg
                border.width: 1
                border.color: queryInput.activeFocus
                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
                    : root.pillBorder
                Behavior on border.color { ColorAnimation { duration: 140 } }

                TextInput {
                    id: queryInput
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.textColor
                    selectionColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
                    selectedTextColor: root.textColor
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
                        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.35)
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
                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.35)
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
                            radius: Math.max(0, root.innerRadius - 2)
                            color: tile.hovered || tile.isFocused ? root.pillBg : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Image {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -8
                                width: 44
                                height: 44
                                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                sourceSize.width: 88
                                sourceSize.height: 88
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 5
                                width: parent.width - 8
                                text: modelData.name
                                color: root.textColor
                                opacity: tile.hovered || tile.isFocused ? 0.95 : 0.72
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 8
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
