import Quickshell
import "."

// Register Theme singleton so other files can use it via "Theme.accent" etc.
singleton Theme {}

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }
}
