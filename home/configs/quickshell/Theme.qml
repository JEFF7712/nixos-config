pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    // Color type properties — use directly as QML colors.
    // withAlpha(c, a) for semi-transparent variants.
    property color background:     "#1e1e2e"
    property color surface:        "#313244"
    property color surfaceVariant: "#45475a"
    property color border:         "#585b70"
    property color text:           "#cdd6f4"
    property color textSubtle:     "#bac2de"
    property color accent:         "#89b4fa"
    property color accentText:     "#1e1e2e"
    property color success:        "#a6e3a1"
    property color warning:        "#f9e2af"
    property color error:          "#f38ba8"

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function _applyColors(raw) {
        if (!raw) return
        try {
            const c = JSON.parse(raw)
            if (c.background)     theme.background     = c.background
            if (c.surface)        theme.surface        = c.surface
            if (c.surfaceVariant) theme.surfaceVariant = c.surfaceVariant
            if (c.border)         theme.border         = c.border
            if (c.text)           theme.text           = c.text
            if (c.textSubtle)     theme.textSubtle     = c.textSubtle
            if (c.accent)         theme.accent         = c.accent
            if (c.accentText)     theme.accentText     = c.accentText
            if (c.success)        theme.success        = c.success
            if (c.warning)        theme.warning        = c.warning
            if (c.error)          theme.error          = c.error
        } catch(e) {
            console.warn("Theme: failed to parse colors.json:", e)
        }
    }

    property FileView _colorFile: FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/colors.json"
        onTextChanged: theme._applyColors(_colorFile.text())
    }

    Component.onCompleted: {
        // FileView may not fire onTextChanged for a file that already exists
        // before quickshell starts — force an initial read.
        Qt.callLater(() => theme._applyColors(_colorFile.text()))
    }
}
