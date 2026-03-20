import Quickshell
import "."
import "./popups"

// Register Theme singleton so other files can use it via "Theme.accent" etc.
singleton Theme {}

ShellRoot {
    // PowerMenu is a PanelWindow (full-screen overlay) and therefore MUST live here
    // at ShellRoot level — it cannot be a child of Bar or RightIsland.
    PowerMenu {
        id: powerMenu
        screen: Quickshell.screens[0]
    }

    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
            onPowerRequested: powerMenu.showing = true
        }
    }
}
