pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick.Effects
import Quickshell.Services.Pipewire
import "RailLogic.js" as RailLogic
import "Logic.js" as Logic

PanelWindow {
    id: line
    readonly property real u: Theme.unit(screen)
    readonly property string here: Desktop.showing[screen.name] ?? ""
    readonly property var desks: RailLogic.workspaceNames(Niri.workspaces, screen.name, Desktop.occupied)
    readonly property var lit: Desktop.windows.find(w => w.focused && w.workspace === line.here) ?? null
    readonly property var player: Media.player
    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
    property string tip: ""
    property real tipX: 0
    anchors {
        left: true
        right: true
        top: true
    }
    implicitHeight: 60 * u
    color: "transparent"
    WlrLayershell.namespace: "folio"
    WlrLayershell.layer: WlrLayer.Bottom
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }
    onDesksChanged: Desktop.noteWaiting(Niri.workspaces.filter(w => w.urgent).map(w => w.name))

    Row {
        id: who
        x: 36 * line.u
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14 * line.u
        readonly property var words: line.lit ? Logic.inFocus(line.lit.app, line.lit.title) : ["", ""]
        Small {
            screen: line.screen
            visible: text.length > 0
            text: who.words[0]
        }
        Small {
            screen: line.screen
            lit: false
            visible: text.length > 0
            width: Math.min(implicitWidth, line.width * 0.14)
            elide: Text.ElideRight
            text: who.words[1]
        }
    }

    Row {
        id: deskRow
        readonly property real gap: 48 * line.u
        x: Math.round(Math.max(who.x + who.width + gap, Math.min((line.width - width) / 2, status.x - gap - width)))
        anchors.verticalCenter: parent.verticalCenter
        spacing: 38 * line.u
        Repeater {
            id: deskItems
            model: line.desks
            Item {
                id: desk
                required property string modelData
                readonly property bool current: modelData === line.here
                readonly property var entry: Niri.workspaces.find(w => w.name === modelData && w.output === line.screen.name)
                width: label.width
                height: label.height
                Row {
                    id: label
                    spacing: 6 * line.u
                    Text {
                        text: desk.modelData
                        color: name.color
                        font {
                            family: Theme.mono
                            pixelSize: 11
                        }
                    }
                    Small {
                        id: name
                        screen: line.screen
                        lit: desk.current || !!desk.entry?.urgent
                        text: Logic.deskName(Desktop.windows, desk.modelData)
                    }
                    Rectangle {
                        visible: !!desk.entry?.urgent
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8 * line.u
                        height: width
                        radius: width / 2
                        color: Theme.signal
                        SequentialAnimation on opacity {
                            running: !!desk.entry?.urgent
                            loops: Animation.Infinite
                            NumberAnimation {
                                to: 0.25
                                duration: 900
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 1
                                duration: 900
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10 * line.u
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Niri.focusDesk(desk.modelData)
                }
            }
        }
    }

    Rectangle {
        readonly property Item under: {
            line.desks;
            return deskItems.count > 0 ? deskItems.itemAt(line.desks.indexOf(line.here)) : null;
        }
        visible: under !== null
        x: deskRow.x + (under ? under.x : 0)
        y: deskRow.y + deskRow.height + 3 * line.u
        width: under ? under.width : 0
        height: 1
        color: Theme.fg
        Behavior on x {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        id: status
        anchors {
            right: parent.right
            rightMargin: 36 * line.u
            verticalCenter: parent.verticalCenter
        }
        spacing: 26 * line.u
        Row {
            visible: line.player !== null
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * line.u
            Small {
                id: playWord
                anchors.verticalCenter: parent.verticalCenter
                screen: line.screen
                lit: false
                text: line.player?.isPlaying ? "playing" : "paused"
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 10 * line.u
                height: width
                radius: width / 2
                color: line.player?.isPlaying ? Theme.fg : "transparent"
                border {
                    width: 1
                    color: Theme.fg
                }
            }
            Small {
                anchors.baseline: playWord.baseline
                screen: line.screen
                link: true
                width: Math.min(implicitWidth, 300 * line.u)
                elide: Text.ElideRight
                text: line.player?.trackTitle || line.player?.identity || ""
                onPressed: event => {
                    if (event.button === Qt.RightButton)
                        line.player.next();
                    else if (event.button === Qt.MiddleButton)
                        line.player.previous();
                    else
                        line.player.togglePlaying();
                }
            }
        }
        MachineRow {
            anchors.verticalCenter: parent.verticalCenter
            window: line
            screen: line.screen
            items: ["power"]
        }
        Small {
            anchors.verticalCenter: parent.verticalCenter
            screen: line.screen
            link: true
            lit: !line.audio?.muted
            text: line.audio ? (line.audio.muted ? "muted" : "vol " + Math.round(line.audio.volume * 100)) : "vol —"
            onPressed: event => {
                if (event.button === Qt.RightButton)
                    Quickshell.execDetached(["pavucontrol"]);
                else if (line.audio)
                    line.audio.muted = !line.audio.muted;
            }
            property real turned: 0
            onWheeled: event => {
                if (!line.audio)
                    return;
                turned += event.angleDelta.y;
                const notches = turned > 0 ? Math.floor(turned / 120) : Math.ceil(turned / 120);
                if (notches === 0)
                    return;
                turned -= notches * 120;
                line.audio.volume = Math.max(0, Math.min(1.5, Math.round(line.audio.volume * 100 + notches * 2) / 100));
            }
        }
    }

    PopupWindow {
        anchor.window: line
        anchor.rect.x: Math.round(Math.max(8, Math.min(line.width - implicitWidth - 8, line.tipX - implicitWidth / 2)))
        anchor.rect.y: line.height
        implicitWidth: Math.ceil(tipText.implicitWidth + 28 * line.u)
        implicitHeight: Math.ceil(tipText.implicitHeight + 18 * line.u)
        visible: line.tip.length > 0 && ShellState.menuItem === null
        color: Theme.bg
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            border {
                width: 1
                color: Theme.faint
            }
        }
        Small {
            id: tipText
            anchors.centerIn: parent
            screen: line.screen
            text: line.tip
        }
    }
}
