import QtQuick
import Quickshell

ShellRoot {
    id: root

    property color themeFg: "#f6f6f6"
    property color themeBg: "#cc2a2a2a"
    property color themeRawBg: "#2a2a2a"
    property color themeAccent: "#f0f0f0"
    property color themeSecond: "#d0d0d0"
    property color themeWarm: "#cfc0a0"
    property color themeFresh: "#b8c8ba"

    Topbar {
        themeFg: root.themeFg
        themeBg: root.themeBg
        themeRawBg: root.themeRawBg
        themeAccent: root.themeAccent
        themeSecond: root.themeSecond
        themeWarm: root.themeWarm
        themeFresh: root.themeFresh
    }
}
