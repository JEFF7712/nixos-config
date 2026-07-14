import QtQuick
import Quickshell
import "internal" as Internal

Scope {
    id: root

    property bool detailedMonitoring: false

    readonly property bool available: model.available
    readonly property bool enabled: model.enabled
    readonly property int connectedCount: model.connectedCount
    readonly property ListModel devices: model.devices

    function setEnabled(enabled: bool): void {
        model.setEnabled(enabled);
    }
    function toggleDevice(id: string): void {
        model.toggleDevice(id);
    }
    function openManager(): void {
        model.openManager();
    }

    Internal.BluetoothModel {
        id: model
        detailedMonitoring: root.detailedMonitoring
    }
}
