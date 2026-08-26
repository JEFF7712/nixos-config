.pragma library

const hiddenIds = ["nm-applet", "nm_applet", "blueman", "blueman-tray", "blueman-applet"];

function isHidden(id) {
    const key = String(id || "").trim().toLowerCase();
    if (key === "")
        return false;
    for (let i = 0; i < hiddenIds.length; i++) {
        if (key === hiddenIds[i])
            return true;
    }
    return false;
}

function visibleItems(items) {
    const list = items || [];
    const out = [];
    for (let i = 0; i < list.length; i++) {
        if (!isHidden(list[i] && list[i].id))
            out.push(list[i]);
    }
    return out;
}
