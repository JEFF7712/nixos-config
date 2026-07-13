import QtQuick
import Quickshell
import Quickshell.Io
import "MediaParser.js" as MediaParser

Scope {
    id: root

    required property var audioService
    property bool detailedMonitoring: false

    property bool _available: false
    property string _status: ""
    property string _title: ""
    property string _artist: ""
    property string _album: ""
    property string _artUrl: ""
    property real _positionSeconds: 0
    property real _lengthSeconds: 0
    property real _playerVolume: 0
    property bool _shuffleEnabled: false
    property bool _volumeIsPlayer: false
    property string _loopMode: "None"
    property var _queue: []
    property var _currentJob: null
    property bool _snapshotPending: false
    property bool _followRequested: true
    property int _followFailures: 0

    readonly property bool available: _available
    readonly property bool playing: _available && _status === "Playing"
    readonly property string status: _status
    readonly property string title: _title
    readonly property string artist: _artist
    readonly property string album: _album
    readonly property string artUrl: _artUrl
    readonly property real positionSeconds: _positionSeconds
    readonly property real lengthSeconds: _lengthSeconds
    readonly property real effectiveVolume: _volumeIsPlayer ? _playerVolume : (audioService.available ? audioService.volumePercent / 100 : 0)
    readonly property bool shuffleEnabled: _shuffleEnabled
    readonly property bool volumeIsPlayer: _volumeIsPlayer
    readonly property string loopMode: _loopMode
    readonly property bool canSeek: _available && _lengthSeconds > 0
    readonly property bool canTogglePlaying: _available
    readonly property bool canGoNext: _available
    readonly property bool canGoPrevious: _available
    readonly property bool canShuffle: _available
    readonly property bool canLoop: _available
    readonly property bool canSetPlayerVolume: _available && _volumeIsPlayer

    readonly property var _snapshotCommand: ["sh", "-c", "playerctl status >/dev/null 2>&1 || { jq -cn '{record:false}'; exit 0; }; nl=$(printf '\\nx'); nl=${nl%x}; status=$(playerctl status 2>/dev/null; printf x); status=${status%x}; status=${status%\"$nl\"}; title=$(playerctl metadata xesam:title 2>/dev/null || true; printf x); title=${title%x}; title=${title%\"$nl\"}; artist=$(playerctl metadata xesam:artist 2>/dev/null || true; printf x); artist=${artist%x}; artist=${artist%\"$nl\"}; album=$(playerctl metadata xesam:album 2>/dev/null || true; printf x); album=${album%x}; album=${album%\"$nl\"}; art=$(playerctl metadata mpris:artUrl 2>/dev/null || true; printf x); art=${art%x}; art=${art%\"$nl\"}; length=$(playerctl metadata mpris:length 2>/dev/null || true); position=$(playerctl position 2>/dev/null || true); shuffle=$(playerctl shuffle 2>/dev/null || true); loop=$(playerctl loop 2>/dev/null || true); if volume=$(playerctl volume 2>/dev/null); then volume_supported=true; else volume=0; volume_supported=false; fi; jq -cn --arg status \"$status\" --arg title \"$title\" --arg artist \"$artist\" --arg album \"$album\" --arg artUrl \"$art\" --arg position \"$position\" --arg length \"$length\" --arg shuffle \"$shuffle\" --arg loop \"$loop\" --arg volume \"$volume\" --argjson volumeSupported \"$volume_supported\" '{record:true,status:$status,title:$title,artist:$artist,album:$album,artUrl:$artUrl,position:$position,length:$length,shuffle:$shuffle,loop:$loop,volume:$volume,volumeSupported:$volumeSupported}'"]

    function _enqueue(command, snapshot, reconcileAfter) {
        _queue = _queue.concat([{command: command, snapshot: snapshot, reconcileAfter: reconcileAfter || false}]);
        _startNext();
    }

    function _startNext() {
        if (commandProcess.running || _queue.length === 0)
            return;
        _currentJob = _queue[0];
        _queue = _queue.slice(1);
        commandProcess.command = _currentJob.command;
        commandProcess.running = true;
    }

    function _snapshotIsRunning() {
        return _currentJob && _currentJob.snapshot;
    }

    function _snapshotIsQueued() {
        return _queue.some(job => job.snapshot);
    }

    function _requestSnapshot() {
        if (_snapshotIsRunning()) {
            _snapshotPending = true;
            return;
        }
        if (_snapshotIsQueued())
            return;
        _enqueue(_snapshotCommand, true, false);
    }

    function _action(argv) {
        if (!_available)
            return;
        _enqueue(["playerctl"].concat(argv), false, true);
    }

    function _applySnapshot(text) {
        const parsed = MediaParser.parseSnapshot(text, commandProcess.exitCode);
        if (parsed === null) {
            try {
                const envelope = JSON.parse(text);
                if (envelope && envelope.record === false)
                    _available = false;
            } catch (error) {
            }
            return;
        }
        _available = true;
        _status = parsed.status;
        _title = parsed.title;
        _artist = parsed.artist;
        _album = parsed.album;
        _artUrl = parsed.artUrl;
        _positionSeconds = parsed.positionSeconds;
        _lengthSeconds = parsed.lengthSeconds;
        _shuffleEnabled = parsed.shuffleEnabled;
        _loopMode = parsed.loopMode;
        _playerVolume = parsed.playerVolume;
        _volumeIsPlayer = parsed.volumeIsPlayer;
    }

    function togglePlaying(): void { _action(["play-pause"]); }
    function next(): void { _action(["next"]); }
    function previous(): void { _action(["previous"]); }
    function seek(seconds: real): void {
        if (canSeek) {
            const target = Math.max(0, Math.min(_lengthSeconds, seconds));
            _positionSeconds = target;
            _action(["position", target.toFixed(2)]);
        }
    }
    function toggleShuffle(): void { if (canShuffle) _action(["shuffle", "Toggle"]); }
    function cycleLoop(): void {
        if (canLoop) {
            const nextMode = _loopMode === "None" ? "Playlist" : _loopMode === "Playlist" ? "Track" : "None";
            _loopMode = nextMode;
            _action(["loop", nextMode]);
        }
    }
    function setEffectiveVolume(value: real): void {
        const volume = Math.max(0, Math.min(1, value));
        const route = MediaParser.volumeRoute(_volumeIsPlayer, audioService.available);
        if (route === "player" && canSetPlayerVolume) {
            _playerVolume = volume;
            _action(["volume", volume.toFixed(2)]);
        } else if (route === "system") {
            audioService.setVolume(Math.round(volume * 100));
        }
    }

    Component.onCompleted: _requestSnapshot()
    Component.onDestruction: {
        _followRequested = false;
        followRetry.stop();
    }

    Process {
        id: followProcess
        running: root._followRequested
        command: ["setpriv", "--pdeathsig", "TERM", "--", "playerctl", "--follow", "metadata", "--format", "{{status}}"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                root._followFailures = 0;
                refreshDebounce.restart();
            }
        }
        onExited: {
            if (!root._followRequested)
                return;
            root._followRequested = false;
            root._followFailures = Math.min(5, root._followFailures + 1);
            followRetry.interval = Math.min(4000, 125 * Math.pow(2, root._followFailures - 1));
            followRetry.restart();
        }
    }

    Timer {
        id: followRetry
        interval: 125
        repeat: false
        onTriggered: root._followRequested = true
    }

    Process {
        id: commandProcess
        stdout: StdioCollector {}
        onExited: {
            const job = root._currentJob;
            if (job && job.snapshot)
                root._applySnapshot(stdout.text);
            root._currentJob = null;
            if (job && job.reconcileAfter) {
                if (root._snapshotIsQueued())
                    refreshDebounce.stop();
                else
                    refreshDebounce.restart();
            }
            if (job && job.snapshot && root._snapshotPending) {
                root._snapshotPending = false;
                root._enqueue(root._snapshotCommand, true, false);
            } else {
                root._startNext();
            }
        }
    }

    Timer {
        id: refreshDebounce
        interval: 120
        repeat: false
        onTriggered: root._requestSnapshot()
    }

    Timer {
        interval: 1500
        running: root.detailedMonitoring
        repeat: true
        triggeredOnStart: true
        onTriggered: root._requestSnapshot()
    }

    Timer {
        interval: 500
        running: root.detailedMonitoring && root.playing
        repeat: true
        onTriggered: root._positionSeconds = root._lengthSeconds > 0 ? Math.min(root._lengthSeconds, root._positionSeconds + 0.5) : root._positionSeconds + 0.5
    }
}
