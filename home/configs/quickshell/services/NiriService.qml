import QtQuick
import Quickshell
import "internal" as Internal

Scope {
    id: root

    readonly property int activeWorkspaceId: model.activeWorkspaceId
    readonly property ListModel workspaces: model.workspaces
    readonly property string focusedTitle: model.focusedTitle
    readonly property string focusedAppId: model.focusedAppId
    readonly property bool streamHealthy: model.streamHealthy
    readonly property string lastError: model.lastError

    function focusWorkspace(output: string, id: int): void {
        model.focusWorkspace(output, id);
    }
    function focusAdjacent(output: string, direction: int): void {
        model.focusAdjacent(output, direction);
    }
    function quitSession(): void {
        model.quitSession();
    }

    Internal.NiriModel {
        id: model
    }
}
