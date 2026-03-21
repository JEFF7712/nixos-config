import QtQuick
import Quickshell
import "."
import "./popups"

ShellRoot {
    id: root

    Bar { id: bar; screen: Quickshell.screens[0] }

    CalendarPopup {
        shown: bar.activePopup === "calendar"
        screen: Quickshell.screens[0]
        onClose: bar.activePopup = ""
    }
    VolumePopup {
        shown: bar.activePopup === "volume"
        screen: Quickshell.screens[0]
        onClose: bar.activePopup = ""
    }
    BrightnessPopup {
        shown: bar.activePopup === "brightness"
        screen: Quickshell.screens[0]
        onClose: bar.activePopup = ""
    }
    MusicPopup {
        shown: bar.activePopup === "music"
        screen: Quickshell.screens[0]
        onClose: bar.activePopup = ""
    }
    QuickSettings {
        shown: bar.activePopup === "quickSettings"
        screen: Quickshell.screens[0]
        onClose: bar.activePopup = ""
    }
    PowerMenu {
        showing: bar.activePopup === "power"
        screen: Quickshell.screens[0]
        onClose: bar.activePopup = ""
    }
}
