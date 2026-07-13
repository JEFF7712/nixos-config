import QtQuick
import Quickshell
import "internal" as Internal

Scope {
    id: root

    property bool detailedMonitoring: false

    readonly property bool available: model.available
    readonly property int chargePercent: model.chargePercent
    readonly property string state: model.state
    readonly property real secondsRemaining: model.secondsRemaining
    readonly property real drawWatts: model.drawWatts
    readonly property int healthPercent: model.healthPercent
    readonly property string profile: model.profile
    readonly property int chargeLimit: model.chargeLimit
    readonly property bool thresholdWritable: model.thresholdWritable
    readonly property bool idleInhibited: model.idleInhibited
    readonly property bool busy: model.busy
    readonly property string lastError: model.lastError

    function setProfile(profile: string): void {
        model.setProfile(profile);
    }
    function cycleProfile(direction: int): void {
        model.cycleProfile(direction);
    }
    function setChargeLimit(percent: int): void {
        model.setChargeLimit(percent);
    }
    function toggleChargeLimit(): void {
        model.toggleChargeLimit();
    }
    function toggleIdleInhibit(): void {
        model.toggleIdleInhibit();
    }

    Internal.PowerModel {
        id: model
        detailedMonitoring: root.detailedMonitoring
    }
}
