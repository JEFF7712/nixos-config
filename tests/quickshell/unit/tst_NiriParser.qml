import QtQuick
import QtTest
import "../../../home/configs/quickshell/services/internal/NiriParser.js" as NiriParser

TestCase {
    name: "NiriParser"

    function workspace(overrides) {
        const base = {
            id: 1,
            idx: 1,
            output: "eDP-1",
            is_urgent: false,
            is_active: false,
            is_focused: false,
            active_window_id: null
        };
        for (const key in overrides || {})
            base[key] = overrides[key];
        return base;
    }

    function test_workspacesAreOrderedByIdAscending() {
        const text = JSON.stringify([workspace({
                idx: 3
            }), workspace({
                idx: 1
            }), workspace({
                idx: 2
            })]);
        const state = NiriParser.reduceWorkspacesSnapshot(NiriParser.initialState(), text, 0);
        compare(state.workspaces.map(ws => ws.id), [1, 2, 3]);
    }

    function test_occupancyFollowsActiveWindowId() {
        const text = JSON.stringify([workspace({
                idx: 1,
                active_window_id: 42
            }), workspace({
                idx: 2,
                active_window_id: null
            }), workspace({
                idx: 3
            })]);
        const state = NiriParser.reduceWorkspacesSnapshot(NiriParser.initialState(), text, 0);
        compare(state.workspaces.map(ws => ws.occupied), [true, false, false]);
    }

    function test_activeAndFocusedSelectionUpdatesActiveWorkspaceId() {
        const focused = JSON.stringify([workspace({
                idx: 1
            }), workspace({
                idx: 2,
                is_focused: true
            })]);
        const focusedState = NiriParser.reduceWorkspacesSnapshot(NiriParser.initialState(), focused, 0);
        compare(focusedState.workspaces.map(ws => ws.active), [false, true]);
        compare(focusedState.activeWorkspaceId, 2);

        const active = JSON.stringify([workspace({
                idx: 1,
                is_active: true
            }), workspace({
                idx: 2
            })]);
        const activeState = NiriParser.reduceWorkspacesSnapshot(NiriParser.initialState(), active, 0);
        compare(activeState.workspaces.map(ws => ws.active), [true, false]);
        compare(activeState.activeWorkspaceId, 1);
    }

    function test_urgentStateIsExposedPerWorkspace() {
        const text = JSON.stringify([workspace({
                idx: 1,
                is_urgent: true
            }), workspace({
                idx: 2
            })]);
        const state = NiriParser.reduceWorkspacesSnapshot(NiriParser.initialState(), text, 0);
        compare(state.workspaces.map(ws => ws.urgent), [true, false]);
    }

    function test_workspaceIdPrefersIdxOverPersistentId() {
        const text = JSON.stringify([workspace({
                id: 99,
                idx: 4
            })]);
        const state = NiriParser.reduceWorkspacesSnapshot(NiriParser.initialState(), text, 0);
        compare(state.workspaces[0].id, 4);
    }

    function test_noActiveWorkspacePreservesPreviousActiveWorkspaceId() {
        const first = NiriParser.reduceWorkspacesSnapshot(NiriParser.initialState(), JSON.stringify([workspace({
                idx: 1,
                is_active: true
            })]), 0);
        compare(first.activeWorkspaceId, 1);
        const second = NiriParser.reduceWorkspacesSnapshot(first, JSON.stringify([workspace({
                idx: 1
            }), workspace({
                idx: 2
            })]), 0);
        compare(second.activeWorkspaceId, 1);
    }

    function test_focusedWindowReadsTitleAndAppId() {
        const state = NiriParser.reduceFocusedWindowSnapshot(NiriParser.initialState(), JSON.stringify({
            id: 1,
            title: "kitty terminal",
            app_id: "kitty"
        }), 0);
        compare(state.focusedTitle, "kitty terminal");
        compare(state.focusedAppId, "kitty");
        compare(state.lastError, "");
    }

    function test_missingFocusedWindowClearsTitleAndAppId() {
        const previous = NiriParser.reduceFocusedWindowSnapshot(NiriParser.initialState(), JSON.stringify({
            title: "kitty terminal",
            app_id: "kitty"
        }), 0);
        const cleared = NiriParser.reduceFocusedWindowSnapshot(previous, "null", 0);
        compare(cleared.focusedTitle, "");
        compare(cleared.focusedAppId, "");
        compare(cleared.lastError, "");
    }

    function test_malformedWorkspacesJsonPreservesLastValidSnapshot() {
        const previous = NiriParser.reduceWorkspacesSnapshot(NiriParser.initialState(), JSON.stringify([workspace({
                idx: 1,
                is_active: true
            })]), 0);
        const malformed = NiriParser.reduceWorkspacesSnapshot(previous, "not json at all", 0);
        compare(malformed.workspaces, previous.workspaces);
        compare(malformed.activeWorkspaceId, previous.activeWorkspaceId);
        compare(malformed.lastError, "failed to parse workspaces snapshot");
    }

    function test_partialWorkspacesJsonIgnoresEntriesMissingAnIdentifier() {
        const text = JSON.stringify([
            {
                is_active: true
            },
            workspace({
                idx: 2
            })]);
        const state = NiriParser.reduceWorkspacesSnapshot(NiriParser.initialState(), text, 0);
        compare(state.workspaces.map(ws => ws.id), [2]);
        compare(state.lastError, "");
    }

    function test_nonArrayWorkspacesPayloadPreservesLastValidSnapshot() {
        const previous = NiriParser.reduceWorkspacesSnapshot(NiriParser.initialState(), JSON.stringify([workspace({
                idx: 1
            })]), 0);
        const malformed = NiriParser.reduceWorkspacesSnapshot(previous, JSON.stringify({
            not: "an array"
        }), 0);
        compare(malformed.workspaces, previous.workspaces);
        compare(malformed.lastError, "failed to parse workspaces snapshot");
    }

    function test_nonzeroExitPreservesEverything() {
        const previous = NiriParser.reduceWorkspacesSnapshot(NiriParser.initialState(), JSON.stringify([workspace({
                idx: 1,
                is_active: true
            })]), 0);
        const failed = NiriParser.reduceWorkspacesSnapshot(previous, JSON.stringify([workspace({
                idx: 5,
                is_active: true
            })]), 1);
        compare(failed.workspaces, previous.workspaces);
        compare(failed.activeWorkspaceId, previous.activeWorkspaceId);
        compare(failed.lastError, "failed to query niri workspaces");

        const previousWindow = NiriParser.reduceFocusedWindowSnapshot(NiriParser.initialState(), JSON.stringify({
            title: "kept",
            app_id: "kept-app"
        }), 0);
        const failedWindow = NiriParser.reduceFocusedWindowSnapshot(previousWindow, JSON.stringify({
            title: "not applied",
            app_id: "not-applied"
        }), 1);
        compare(failedWindow.focusedTitle, "kept");
        compare(failedWindow.focusedAppId, "kept-app");
        compare(failedWindow.lastError, "failed to query niri focused window");
    }

    function test_malformedFocusedWindowJsonPreservesLastValidSnapshot() {
        const previous = NiriParser.reduceFocusedWindowSnapshot(NiriParser.initialState(), JSON.stringify({
            title: "kept",
            app_id: "kept-app"
        }), 0);
        const malformed = NiriParser.reduceFocusedWindowSnapshot(previous, "{not json", 0);
        compare(malformed.focusedTitle, "kept");
        compare(malformed.focusedAppId, "kept-app");
        compare(malformed.lastError, "failed to parse focused-window snapshot");
    }

    function test_partialFocusedWindowJsonPreservesMissingFieldsIndependently() {
        const previous = NiriParser.reduceFocusedWindowSnapshot(NiriParser.initialState(), JSON.stringify({
            title: "kept title",
            app_id: "kept-app"
        }), 0);
        const partial = NiriParser.reduceFocusedWindowSnapshot(previous, JSON.stringify({
            id: 7,
            app_id: "new-app"
        }), 0);
        compare(partial.focusedTitle, "kept title");
        compare(partial.focusedAppId, "new-app");
        compare(partial.lastError, "");
    }

    function test_classifiesEveryConsumedWorkspaceEventClass() {
        for (const name of ["WorkspacesChanged", "WorkspaceUrgencyChanged", "WorkspaceActivated", "WorkspaceActiveWindowChanged"]) {
            const result = NiriParser.classifyEventLine(JSON.stringify({
                [name]: {}
            }));
            verify(result.ok, name + " should classify as ok");
            compare(result.kind, "workspaces");
            compare(result.name, name);
        }
    }

    function test_classifiesEveryConsumedWindowEventClass() {
        for (const name of ["WindowsChanged", "WindowOpenedOrChanged", "WindowClosed", "WindowFocusChanged", "WindowUrgencyChanged"]) {
            const result = NiriParser.classifyEventLine(JSON.stringify({
                [name]: {}
            }));
            verify(result.ok, name + " should classify as ok");
            compare(result.kind, "focused-window");
            compare(result.name, name);
        }
    }

    function test_classifiesUnknownEventClassesAsIgnoredButValid() {
        const result = NiriParser.classifyEventLine(JSON.stringify({
            KeyboardLayoutSwitched: {
                idx: 1
            }
        }));
        verify(result.ok);
        compare(result.kind, "ignored");
        compare(result.name, "KeyboardLayoutSwitched");
    }

    function test_classifyRejectsMalformedAndMultiKeyAndEmptyLines() {
        compare(NiriParser.classifyEventLine("not json").ok, false);
        compare(NiriParser.classifyEventLine("").ok, false);
        compare(NiriParser.classifyEventLine("   ").ok, false);
        compare(NiriParser.classifyEventLine(JSON.stringify([1, 2])).ok, false);
        compare(NiriParser.classifyEventLine(JSON.stringify({
            WorkspacesChanged: {},
            WindowsChanged: {}
        })).ok, false);
    }

    function test_consumeEventChunkBuffersPartialLinesAcrossChunks() {
        const first = NiriParser.consumeEventChunk("", '{"WorkspacesChanged"');
        compare(first.lines, []);
        compare(first.buffer, '{"WorkspacesChanged"');

        const second = NiriParser.consumeEventChunk(first.buffer, ':{}}\n{"WindowClosed":{"id":1}}\n');
        compare(second.lines, ['{"WorkspacesChanged":{}}', '{"WindowClosed":{"id":1}}']);
        compare(second.buffer, "");
    }

    function test_consumeEventChunkKeepsTrailingPartialLine() {
        const result = NiriParser.consumeEventChunk("", '{"WindowsChanged":{}}\n{"Window');
        compare(result.lines, ['{"WindowsChanged":{}}']);
        compare(result.buffer, '{"Window');
    }
}
