import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    AppLauncher { id: launcher }

    // Fullscreen transparent catcher one layer below the popup so clicks
    // outside the card close it without dragging blur over the whole screen.
    PanelWindow {
        visible: launcher.shown
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: -1
        color: "transparent"
        WlrLayershell.namespace: "quickshell-app-launcher-catcher"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.close()
        }
    }
}
