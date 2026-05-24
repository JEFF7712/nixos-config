import QtQuick
import Quickshell

InfoPopup {
    id: root
    title: "POWER"

    function exec(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd])
        root.close()
    }

    ActionRow {
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        icon: "󰌾"
        label: "lock"
        onActivated: root.exec("loginctl lock-session")
    }
    ActionRow {
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        icon: "󰒲"
        label: "sleep"
        onActivated: root.exec("systemctl suspend")
    }
    ActionRow {
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        icon: "󰍃"
        label: "logout"
        onActivated: root.exec("niri msg action quit -s")
    }
    ActionRow {
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        icon: "󰜉"
        label: "restart"
        onActivated: root.exec("systemctl reboot")
    }
    ActionRow {
        themeFg: root.themeFg
        themeAccent: root.themeAccent
        icon: "󰐥"
        label: "shutdown"
        onActivated: root.exec("systemctl poweroff")
    }
}
