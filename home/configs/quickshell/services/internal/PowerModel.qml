import QtQuick
import Quickshell
import Quickshell.Io
import "PowerParser.js" as PowerParser

Scope {
    id: root

    property bool detailedMonitoring: false

    property bool _available: false
    property int _chargePercent: 0
    property string _state: "unknown"
    property real _secondsRemaining: 0
    property real _drawWatts: 0
    property int _healthPercent: 0
    property string _profile: "unknown"
    property int _chargeLimit: 100
    property bool _thresholdWritable: false
    property bool _idleInhibited: false
    property string _thresholdError: ""
    property string _stasisError: ""
    property var _queue: []
    property var _currentJob: null
    property bool _probePending: false

    readonly property bool available: _available
    readonly property int chargePercent: _chargePercent
    readonly property string state: _state
    readonly property real secondsRemaining: _secondsRemaining
    readonly property real drawWatts: _drawWatts
    readonly property int healthPercent: _healthPercent
    readonly property string profile: _profile
    readonly property int chargeLimit: _chargeLimit
    readonly property bool thresholdWritable: _thresholdWritable
    readonly property bool idleInhibited: _idleInhibited
    readonly property bool busy: commandProcess.running || _queue.length > 0
    readonly property string lastError: _thresholdError || _stasisError
    readonly property string _thresholdPath: Quickshell.env("QS_POWER_THRESHOLD_PATH") || "/sys/class/power_supply/BAT0/charge_control_end_threshold"
    readonly property string _probePath: Qt.resolvedUrl("power-probe").toString().replace("file://", "")
    readonly property var _probeCommand: ["setpriv", "--pdeathsig", "TERM", "--", _probePath]

    function _stateObject(): var {
        return {
            available: _available,
            chargePercent: _chargePercent,
            state: _state,
            secondsRemaining: _secondsRemaining,
            drawWatts: _drawWatts,
            healthPercent: _healthPercent,
            profile: _profile,
            chargeLimit: _chargeLimit,
            thresholdWritable: _thresholdWritable,
            idleInhibited: _idleInhibited,
            thresholdError: _thresholdError,
            stasisError: _stasisError,
            lastError: lastError
        };
    }

    function _apply(state): void {
        _available = state.available;
        _chargePercent = state.chargePercent;
        _state = state.state;
        _secondsRemaining = state.secondsRemaining;
        _drawWatts = state.drawWatts;
        _healthPercent = state.healthPercent;
        _profile = state.profile;
        _chargeLimit = state.chargeLimit;
        _thresholdWritable = state.thresholdWritable;
        _idleInhibited = state.idleInhibited;
        _thresholdError = state.thresholdError;
        _stasisError = state.stasisError;
    }

    function _enqueue(command, kind, errorDomain): void {
        _queue = _queue.concat([
            {
                command: command,
                kind: kind,
                errorDomain: errorDomain || ""
            }
        ]);
        _startNext();
    }

    function _startNext(): void {
        if (commandProcess.running || _queue.length === 0)
            return;
        _currentJob = _queue[0];
        _queue = _queue.slice(1);
        commandProcess.command = _currentJob.command;
        commandProcess.running = true;
    }

    function _requestProbe(): void {
        if (_currentJob && _currentJob.kind === "probe") {
            _probePending = true;
            return;
        }
        if (_queue.some(job => job.kind === "probe"))
            return;
        _enqueue(_probeCommand, "probe", "");
    }

    function _action(command, errorDomain): void {
        _enqueue(command, "action", errorDomain);
    }

    function setProfile(profile: string): void {
        if (["power-saver", "balanced", "performance"].indexOf(profile) === -1)
            return;
        _profile = profile;
        _action(["setpriv", "--pdeathsig", "TERM", "--", "powerprofilesctl", "set", profile], "");
    }

    function cycleProfile(direction: int): void {
        const order = ["power-saver", "balanced", "performance"];
        let index = order.indexOf(_profile);
        if (index < 0)
            index = 1;
        const step = direction < 0 ? -1 : 1;
        setProfile(order[(index + step + order.length) % order.length]);
    }

    function setChargeLimit(percent: int): void {
        if (!_thresholdWritable)
            return;
        const target = Math.max(0, Math.min(100, percent));
        _action(["setpriv", "--pdeathsig", "TERM", "--", "sh", "-c", "printf '%s\\n' \"$1\" | setpriv --pdeathsig TERM -- tee \"$2\" >/dev/null", "power-threshold", String(target), _thresholdPath], "threshold");
    }

    function toggleChargeLimit(): void {
        setChargeLimit(_chargeLimit >= 100 ? 80 : 100);
    }

    function toggleIdleInhibit(): void {
        _action(["setpriv", "--pdeathsig", "TERM", "--", "stasis", "toggle-inhibit"], "stasis");
    }

    Component.onCompleted: _requestProbe()
    Component.onDestruction: {
        pollTimer.stop();
        refreshDebounce.stop();
        _queue = [];
        commandProcess.running = false;
    }

    onDetailedMonitoringChanged: {
        pollTimer.restart();
        if (detailedMonitoring)
            _requestProbe();
    }

    Process {
        id: commandProcess
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            const job = root._currentJob;
            if (job && job.kind === "probe") {
                const next = PowerParser.reduceSnapshot(root._stateObject(), stdout.text, exitCode);
                root._apply(next);
            } else if (job && job.kind === "action") {
                const errors = PowerParser.reduceAdapterResult(root._stateObject(), job.errorDomain, exitCode === 0);
                root._thresholdError = errors.thresholdError;
                root._stasisError = errors.stasisError;
                refreshDebounce.restart();
            }
            root._currentJob = null;
            if (job && job.kind === "probe" && root._probePending) {
                root._probePending = false;
                root._enqueue(root._probeCommand, "probe", "");
            } else {
                root._startNext();
            }
        }
    }

    Timer {
        id: refreshDebounce
        interval: 100
        repeat: false
        onTriggered: root._requestProbe()
    }

    Timer {
        id: pollTimer
        interval: root.detailedMonitoring ? 5000 : 30000
        running: true
        repeat: true
        onTriggered: root._requestProbe()
    }
}
