.pragma library

// Event names that need a fresh `niri msg -j workspaces` (single source of truth).
var WORKSPACE_EVENT_NAMES = ["WorkspacesChanged", "WorkspaceUrgencyChanged", "WorkspaceActivated", "WorkspaceActiveWindowChanged"];

// WindowFocusChanged only carries an id; re-poll for title/app_id.
var WINDOW_EVENT_NAMES = ["WindowsChanged", "WindowOpenedOrChanged", "WindowClosed", "WindowFocusChanged", "WindowUrgencyChanged"];

function initialState() {
    return {
        activeWorkspaceId: 0,
        workspaces: [],
        focusedTitle: "",
        focusedAppId: "",
        lastError: ""
    };
}

function copyState(previous) {
    const base = previous || initialState();
    return {
        activeWorkspaceId: base.activeWorkspaceId || 0,
        workspaces: (base.workspaces || []).map(ws => ({
                id: ws.id,
                output: ws.output,
                occupied: ws.occupied,
                active: ws.active,
                urgent: ws.urgent
            })),
        focusedTitle: base.focusedTitle || "",
        focusedAppId: base.focusedAppId || "",
        lastError: base.lastError || ""
    };
}

// niri `idx` is the per-output number `focus-workspace` accepts; `id` is not contiguous.
function _workspaceRefId(ws) {
    return ws.idx || ws.id;
}

function reduceWorkspacesSnapshot(previous, text, exitCode) {
    const next = copyState(previous);
    if ((exitCode || 0) !== 0) {
        next.lastError = "failed to query niri workspaces";
        return next;
    }

    let parsed;
    try {
        parsed = JSON.parse(text);
    } catch (error) {
        next.lastError = "failed to parse workspaces snapshot";
        return next;
    }
    if (!Array.isArray(parsed)) {
        next.lastError = "failed to parse workspaces snapshot";
        return next;
    }

    const list = [];
    let activeId = next.activeWorkspaceId;
    for (const ws of parsed) {
        if (!ws || typeof ws !== "object")
            continue;
        const id = _workspaceRefId(ws);
        if (id === undefined || id === null)
            continue;
        const occupied = ws.active_window_id !== null && ws.active_window_id !== undefined;
        const active = ws.is_focused === true || ws.is_active === true;
        const urgent = ws.is_urgent === true;
        list.push({
            id: id,
            output: typeof ws.output === "string" ? ws.output : "",
            occupied: occupied,
            active: active,
            urgent: urgent
        });
        if (active)
            activeId = id;
    }
    list.sort((a, b) => a.id - b.id);

    next.workspaces = list;
    next.activeWorkspaceId = activeId;
    next.lastError = "";
    return next;
}

// JSON `null` = no focused window (clear fields). Parse/exit failure keeps the previous title/app_id.
function reduceFocusedWindowSnapshot(previous, text, exitCode) {
    const next = copyState(previous);
    if ((exitCode || 0) !== 0) {
        next.lastError = "failed to query niri focused window";
        return next;
    }

    let parsed;
    try {
        parsed = JSON.parse(text);
    } catch (error) {
        next.lastError = "failed to parse focused-window snapshot";
        return next;
    }

    if (parsed === null) {
        next.focusedTitle = "";
        next.focusedAppId = "";
        next.lastError = "";
        return next;
    }
    if (typeof parsed !== "object" || Array.isArray(parsed)) {
        next.lastError = "failed to parse focused-window snapshot";
        return next;
    }

    if (typeof parsed.title === "string")
        next.focusedTitle = parsed.title;
    if (typeof parsed.app_id === "string")
        next.focusedAppId = parsed.app_id;
    next.lastError = "";
    return next;
}

function consumeEventChunk(buffer, chunk) {
    const lines = (buffer + chunk).split("\n");
    const remainder = lines.pop();
    return {
        buffer: remainder,
        lines: lines
    };
}

// Unknown single-key events (e.g. KeyboardLayoutSwitched) are ignored, not invalid.
function classifyEventLine(line) {
    const trimmed = String(line || "").trim();
    if (!trimmed)
        return {
            ok: false
        };

    let parsed;
    try {
        parsed = JSON.parse(trimmed);
    } catch (error) {
        return {
            ok: false
        };
    }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
        return {
            ok: false
        };

    const keys = Object.keys(parsed);
    if (keys.length !== 1)
        return {
            ok: false
        };

    const name = keys[0];
    if (WORKSPACE_EVENT_NAMES.indexOf(name) !== -1)
        return {
            ok: true,
            name: name,
            kind: "workspaces"
        };
    if (WINDOW_EVENT_NAMES.indexOf(name) !== -1)
        return {
            ok: true,
            name: name,
            kind: "focused-window"
        };
    return {
        ok: true,
        name: name,
        kind: "ignored"
    };
}
