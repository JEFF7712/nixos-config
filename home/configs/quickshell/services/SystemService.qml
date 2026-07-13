import QtQuick
import Quickshell
import "internal" as Internal

Scope {
    id: root

    property bool detailedMonitoring: false

    readonly property bool available: model.available
    readonly property int cpuPercent: model.cpuPercent
    readonly property real ramUsedGiB: model.ramUsedGiB
    readonly property int ramPercent: model.ramPercent
    readonly property int diskPercent: model.diskPercent
    readonly property string hostName: model.hostName
    readonly property string kernel: model.kernel
    readonly property string uptime: model.uptime
    readonly property string nixGeneration: model.nixGeneration
    readonly property string lastError: model.lastError

    function lock(): void {
        model.lock();
    }
    function suspend(): void {
        model.suspend();
    }
    function reboot(): void {
        model.reboot();
    }
    function powerOff(): void {
        model.powerOff();
    }

    Internal.SystemModel {
        id: model
        detailedMonitoring: root.detailedMonitoring
    }
}
