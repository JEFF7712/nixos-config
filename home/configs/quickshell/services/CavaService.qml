import QtQuick
import Quickshell
import Quickshell.Io
import "internal/CavaParser.js" as CavaParser

Scope {
    id: root

    property bool playing: false
    property bool requested: false
    readonly property list<int> values: root._values

    readonly property string _configPath: Qt.resolvedUrl("../cava-bar.conf").toString().replace("file://", "")
    property list<int> _values: []
    property string _buffer: ""
    property int _retryIndex: 0
    property bool _intentionalStop: false
    property bool _stopping: false
    property bool _restartAfterStop: false
    property bool _processExpected: false
    property bool _terminalHandled: true

    function _clear(): void {
        _buffer = "";
        _values = CavaParser.clear();
    }

    function _consume(data: string): void {
        const parsed = CavaParser.consume(_buffer, data);
        _buffer = parsed.buffer;
        if (parsed.frames.length === 0)
            return;
        _values = parsed.frames[parsed.frames.length - 1];
        _retryIndex = 0;
        retryTimer.stop();
    }

    function _start(): void {
        if (!(playing && requested))
            return;
        if (_stopping) {
            _restartAfterStop = true;
            return;
        }
        if (cavaProcess.running || retryTimer.running)
            return;
        _intentionalStop = false;
        _processExpected = true;
        _terminalHandled = false;
        terminalFallback.stop();
        cavaProcess.running = true;
    }

    function _handleTermination(): void {
        if (_terminalHandled)
            return;
        _terminalHandled = true;
        _processExpected = false;
        _clear();
        if (_stopping) {
            _stopping = false;
            const restart = _restartAfterStop && playing && requested;
            _restartAfterStop = false;
            _intentionalStop = false;
            if (restart)
                _start();
            return;
        }
        if (_intentionalStop || !(playing && requested))
            return;
        if (_retryIndex >= 3)
            return;
        retryTimer.interval = [250, 500, 1000][_retryIndex];
        _retryIndex++;
        retryTimer.start();
    }

    function _stop(): void {
        _intentionalStop = true;
        retryTimer.stop();
        _retryIndex = 0;
        _restartAfterStop = false;
        _clear();
        if (cavaProcess.running) {
            _stopping = true;
            cavaProcess.running = false;
        }
    }

    function _syncDemand(): void {
        if (playing && requested)
            _start();
        else
            _stop();
    }

    onPlayingChanged: _syncDemand()
    onRequestedChanged: _syncDemand()

    Process {
        id: cavaProcess
        command: ["setpriv", "--pdeathsig", "TERM", "--", "cava", "-p", root._configPath]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root._consume(data)
        }
        onRunningChanged: {
            if (!running && root._processExpected && !root._terminalHandled)
                terminalFallback.restart();
        }
        onExited: {
            terminalFallback.stop();
            root._handleTermination();
        }
    }

    Timer {
        id: terminalFallback
        interval: 0
        repeat: false
        onTriggered: root._handleTermination()
    }

    Timer {
        id: retryTimer
        repeat: false
        onTriggered: root._start()
    }

    Component.onCompleted: _syncDemand()
    Component.onDestruction: _stop()
}
