import QtQuick
import Quickshell
import Quickshell.Wayland
import "../ilya/WindowRegistry.js" as LayoutMath

PanelWindow {
    id: root

    property bool shown: false
    property string layoutName: ""
    property string contentSource: ""
    signal close()

    visible: shown
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "bar-popup"

    readonly property var popupLayout: screen
        ? LayoutMath.getLayout(layoutName, 0, 0, screen.width, screen.height, 1.0)
        : null

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Loader {
        id: popupLoader
        active: root.shown && root.popupLayout !== null && root.contentSource !== ""
        asynchronous: false
        x: root.popupLayout ? root.popupLayout.x : 0
        y: root.popupLayout ? root.popupLayout.y : 0
        width: root.popupLayout ? root.popupLayout.w : 0
        height: root.popupLayout ? root.popupLayout.h : 0
        z: 1
        source: root.contentSource

        onLoaded: {
            if (item) {
                item.focus = true
                if (item.forceActiveFocus) {
                    item.forceActiveFocus()
                }
            }
        }
    }
}
