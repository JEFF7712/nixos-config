import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Volume / mic / brightness feedback for the media keys. Same IPC surface as
// the repo bar's `osd` target, so volume-adjust and brightness-adjust drive
// whichever shell is running.
PanelWindow {
    id: osd
    property string label: ""
    property int percent: 0
    property bool muted: false
    readonly property real u: Theme.unit(screen)
    screen: ShellState.focusedScreen
    visible: shown > 0
    property real shown: 0
    Behavior on shown {
        NumberAnimation {
            duration: 120
        }
    }
    anchors.top: true
    margins.top: 70 * u
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 420 * u
    implicitHeight: box.implicitHeight
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "folio"
    WlrLayershell.layer: WlrLayer.Overlay

    function show(what: string, value: int, silent: bool): void {
        label = what;
        percent = Math.max(0, Math.min(150, value));
        muted = silent;
        shown = 1;
        hide.restart();
    }
    Timer {
        id: hide
        interval: 1400
        onTriggered: osd.shown = 0
    }
    IpcHandler {
        target: "osd"
        function showVolume(label: string, percent: int, muted: bool): string {
            osd.show("vol · " + label, percent, muted);
            return "ok";
        }
        function showMic(label: string, percent: int, muted: bool): string {
            osd.show("mic · " + label, percent, muted);
            return "ok";
        }
        function showBrightness(label: string, percent: int): string {
            osd.show("lum · " + label, percent, false);
            return "ok";
        }
        function showStatus(glyph: string, label: string, badge: string): string {
            osd.show(label + (badge ? " · " + badge : ""), -1, false);
            return "ok";
        }
    }

    Rectangle {
        id: box
        width: parent.width
        implicitHeight: column.implicitHeight + 36 * osd.u
        opacity: osd.shown
        color: Theme.bg
        border {
            width: 1
            color: Theme.fg
        }
        Column {
            id: column
            x: 18 * osd.u
            y: 18 * osd.u
            width: parent.width - 36 * osd.u
            spacing: 12 * osd.u
            Row {
                width: parent.width
                Small {
                    id: what
                    screen: osd.screen
                    width: parent.width - amount.width
                    elide: Text.ElideRight
                    text: osd.label
                }
                Small {
                    id: amount
                    screen: osd.screen
                    lit: !osd.muted
                    visible: osd.percent >= 0
                    text: osd.muted ? "muted" : osd.percent
                }
            }
            Item {
                visible: osd.percent >= 0
                width: parent.width
                height: 6 * osd.u
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    color: Theme.faint
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * Math.min(1, osd.percent / 100)
                    height: parent.height
                    color: osd.muted ? Theme.dim : (osd.percent > 100 ? Theme.signal : Theme.fg)
                }
            }
        }
    }
}
