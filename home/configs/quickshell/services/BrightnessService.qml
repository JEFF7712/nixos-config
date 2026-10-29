import QtQuick
import Quickshell
import "internal" as Internal

Scope {
    id: root

    property bool detailedMonitoring: false

    readonly property var displays: model.displays
    readonly property bool available: model.available
    readonly property int averagePercent: model.averagePercent
    readonly property bool busy: model.busy
    readonly property string lastError: model.lastError

    function displayPercent(id: string): int {
        return model.displayPercent(id);
    }

    function refresh(): void {
        model.refresh();
    }

    function setBrightness(id: string, percent: int): void {
        model.setBrightness(id, percent);
    }

    function adjustAll(direction: int): void {
        model.adjustAll(direction);
    }

    Internal.BrightnessModel {
        id: model
        detailedMonitoring: root.detailedMonitoring
    }
}
