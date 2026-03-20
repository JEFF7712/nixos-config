pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: theme

    property string background:     "#1e1e2e"
    property string surface:        "#313244"
    property string surfaceVariant: "#45475a"
    property string border:         "#585b70"
    property string text:           "#cdd6f4"
    property string textSubtle:     "#bac2de"
    property string accent:         "#89b4fa"
    property string accentText:     "#1e1e2e"
    property string success:        "#a6e3a1"
    property string warning:        "#f9e2af"
    property string error:          "#f38ba8"

    // Called whenever colors.json changes on disk
    function _applyColors(raw) {
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
        // FileView.text() is a function; textChanged fires when the file
        // is (re)loaded. We call text() inside the handler to get the content.
        path: Quickshell.env("HOME") + "/.local/state/quickshell/colors.json"
        onTextChanged: theme._applyColors(_colorFile.text())
    }
}
