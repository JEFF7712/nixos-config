import QtQuick
import Quickshell
import Quickshell.Io
import "SystemParser.js" as SystemParser

Scope {
    id: root

    property bool detailedMonitoring: false

    property bool _available: false
    property int _cpuPercent: 0
    property real _ramUsedGiB: 0
    property int _ramPercent: 0
    property int _diskPercent: 0
    property string _hostName: ""
    property string _kernel: ""
    property string _uptime: ""
    property string _nixGeneration: ""
    property string _lastError: ""

    readonly property bool available: _available
    readonly property int cpuPercent: _cpuPercent
    readonly property real ramUsedGiB: _ramUsedGiB
    readonly property int ramPercent: _ramPercent
    readonly property int diskPercent: _diskPercent
    readonly property string hostName: _hostName
    readonly property string kernel: _kernel
    readonly property string uptime: _uptime
    readonly property string nixGeneration: _nixGeneration
    readonly property string lastError: _lastError

    function _stateObject(): var {
        return {
            available: _available,
            cpuPercent: _cpuPercent,
            ramUsedGiB: _ramUsedGiB,
            ramPercent: _ramPercent,
            diskPercent: _diskPercent,
            hostName: _hostName,
            kernel: _kernel,
            uptime: _uptime,
            nixGeneration: _nixGeneration,
            lastError: _lastError
        };
    }

    function _applyMetrics(state): void {
        _available = state.available;
        _cpuPercent = state.cpuPercent;
        _ramUsedGiB = state.ramUsedGiB;
        _ramPercent = state.ramPercent;
        _diskPercent = state.diskPercent;
        _lastError = state.lastError;
    }

    function _applyMetadata(state): void {
        _hostName = state.hostName;
        _kernel = state.kernel;
        _uptime = state.uptime;
        _nixGeneration = state.nixGeneration;
    }

    function _requestMetrics(): void {
        if (metricsProcess.running)
            return;
        metricsProcess.running = true;
    }

    function _requestMetadata(): void {
        if (metadataProcess.running)
            return;
        metadataProcess.running = true;
    }

    function lock(): void {
        Quickshell.execDetached(["lock-screen"]);
    }

    function suspend(): void {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function reboot(): void {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function powerOff(): void {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    Component.onCompleted: {
        root._requestMetrics();
        root._requestMetadata();
    }
    Component.onDestruction: {
        metricsTimer.stop();
        metadataTimer.stop();
        metricsProcess.running = false;
        metadataProcess.running = false;
    }

    onDetailedMonitoringChanged: {
        if (detailedMonitoring)
            root._requestMetadata();
    }

    Process {
        id: metricsProcess
        command: ["sh", "-c", SystemParser.METRICS_COMMAND]
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root._applyMetrics(SystemParser.reduceMetricsSnapshot(root._stateObject(), stdout.text, exitCode));
        }
    }

    Process {
        id: metadataProcess
        command: ["sh", "-c", SystemParser.METADATA_COMMAND]
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root._applyMetadata(SystemParser.reduceMetadataSnapshot(root._stateObject(), stdout.text, exitCode));
        }
    }

    Timer {
        id: metricsTimer
        interval: 3000
        running: true
        repeat: true
        onTriggered: root._requestMetrics()
    }

    Timer {
        id: metadataTimer
        interval: 30000
        running: root.detailedMonitoring
        repeat: true
        onTriggered: root._requestMetadata()
    }
}
