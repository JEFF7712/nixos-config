.pragma library

// Event classes that require a fresh "niri msg -j workspaces" snapshot.
// Niri's event stream always leads with a full-state event per class, but
// we still re-request through the same owned snapshot command used at
// startup so field derivation (idx/id selection, occupancy, urgency) has a
// single source of truth.
var WORKSPACE_EVENT_NAMES = ["WorkspacesChanged", "WorkspaceUrgencyChanged", "WorkspaceActivated", "WorkspaceActiveWindowChanged"];

// Event classes that require a fresh "niri msg -j focused-window" snapshot.
// WindowFocusChanged only carries an id (or null); re-polling for the title
// and app_id avoids maintaining a second, window-list-derived source of
// truth for focused-window text.
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
                occupied: ws.occupied,
                active: ws.active,
                urgent: ws.urgent
            })),
        focusedTitle: base.focusedTitle || "",
        focusedAppId: base.focusedAppId || "",
        lastError: base.lastError || ""
    };
}

// Niri's "idx" is the per-output number niri displays and that
// "focus-workspace" accepts as a reference; "id" is a persistent id that is
// not contiguous across outputs. Matches the previous Topbar adapter's
// `ws.idx || ws.id` selection exactly, including idx-0 falling back to id
// (niri workspace indices are 1-based in practice, so this is not observed).
function _workspaceRefId(ws) {
    return ws.idx || ws.id;
}

// Preserves the entire previous workspaces snapshot (and activeWorkspaceId)
// on a nonzero exit or unparseable/non-array output, per the "last complete
// valid snapshot" error-handling contract.
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

// A JSON `null` body means niri genuinely has no focused window right now
// (confirmed against a live "niri msg -j focused-window" on an empty
// workspace) and is treated as valid, clearing both fields. A response that
// fails to parse, or a nonzero exit, instead preserves the previous
// title/app_id. A parsed object independently preserves either field when
// it is missing or not a string, mirroring SystemParser's per-field
// metadata preservation.
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

// Buffers a raw stdout chunk against a carried-over partial line and
// returns every complete (newline-terminated) line plus the new remainder,
// mirroring CavaParser.consume's chunk/partial-record handling.
function consumeEventChunk(buffer, chunk) {
    const lines = (buffer + chunk).split("\n");
    const remainder = lines.pop();
    return {
        buffer: remainder,
        lines: lines
    };
}

// Classifies one complete event-stream line. Malformed JSON, a non-object
// payload, or an envelope without exactly one event-name key is reported as
// invalid (`ok: false`) and must not update any state. A recognized event
// name is classified into the snapshot it should refresh; any other valid
// single-key event object (e.g. KeyboardLayoutSwitched) is classified as
// "ignored" -- still proof the stream is healthy, but not consumed further.
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
