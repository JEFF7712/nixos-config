import QtQuick
import Quickshell
import "."
import "./popups"

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: QtObject {
            required property var modelData

            property var _bar: Bar {
                id: bar
                screen: modelData
            }

            property var _cal: CalendarPopup {
                shown: bar.activePopup === "calendar"
                screen: modelData
                onClose: bar.activePopup = ""
            }
            property var _vol: VolumePopup {
                shown: bar.activePopup === "volume"
                screen: modelData
                onClose: bar.activePopup = ""
            }
            property var _bri: BrightnessPopup {
                shown: bar.activePopup === "brightness"
                screen: modelData
                onClose: bar.activePopup = ""
            }
            property var _music: MusicPopup {
                shown: bar.activePopup === "music"
                screen: modelData
                onClose: bar.activePopup = ""
            }
            property var _qs: QuickSettings {
                shown: bar.activePopup === "quickSettings"
                screen: modelData
                onClose: bar.activePopup = ""
            }
            property var _power: PowerMenu {
                showing: bar.activePopup === "power"
                screen: modelData
                onClose: bar.activePopup = ""
            }
        }
    }
}
