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

    function focusWorkspace(id: int): void {
        model.focusWorkspace(id);
    }
    function focusAdjacent(direction: int): void {
        model.focusAdjacent(direction);
    }
    function quitSession(): void {
        model.quitSession();
    }

    Internal.NiriModel {
        id: model
    }
}
