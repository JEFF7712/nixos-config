import QtQuick
import Quickshell
import Quickshell.Wayland

// Sits in niri's backdrop (see the folio profile's layer-rule) so workspace
// switches show paper, not the void. niri gives backdrop layers no input, so
// the interactive Page stays on the normal background layer above it.
PanelWindow {
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bg
    mask: Region {}
    WlrLayershell.namespace: "folio-backdrop"
    WlrLayershell.layer: WlrLayer.Background
}
