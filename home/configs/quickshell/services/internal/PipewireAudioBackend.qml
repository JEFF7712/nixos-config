import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root

    readonly property bool available: state.available
    readonly property int volumePercent: state.volumePercent
    readonly property bool muted: state.muted

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: root.sink ? root.sink.audio : null

    function syncFromNative(): void {
        const sinkPresent = root.sink !== null && root.sink !== undefined;
        const audioPresent = root.sinkAudio !== null && root.sinkAudio !== undefined;
        const volume = audioPresent ? root.sinkAudio.volume : NaN;
        const valid = Pipewire.ready
            && sinkPresent
            && root.sink.ready
            && audioPresent
            && typeof volume === "number"
            && isFinite(volume);

        if (!valid) {
            state.available = false;
            return;
        }

        state.volumePercent = Math.max(0, Math.min(100, Math.round(volume * 100)));
        state.muted = Boolean(root.sinkAudio.muted);
        state.available = true;
    }

    function setVolume(percent: int): void {
        if (!root.available || root.sinkAudio === null || root.sinkAudio === undefined)
            return;
        root.sinkAudio.volume = Math.max(0, Math.min(100, percent)) / 100;
    }

    function setMuted(value: bool): void {
        if (!root.available || root.sinkAudio === null || root.sinkAudio === undefined)
            return;
        root.sinkAudio.muted = value;
    }

    property QtObject state: QtObject {
        property bool available: false
        property int volumePercent: 0
        property bool muted: false
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    Connections {
        target: Pipewire

        function onReadyChanged(): void {
            root.syncFromNative();
        }

        function onDefaultAudioSinkChanged(): void {
            root.syncFromNative();
        }
    }

    Connections {
        target: root.sink

        function onReadyChanged(): void {
            root.syncFromNative();
        }
    }

    Connections {
        target: root.sinkAudio

        function onVolumesChanged(): void {
            root.syncFromNative();
        }

        function onMutedChanged(): void {
            root.syncFromNative();
        }
    }

    onSinkChanged: root.syncFromNative()
    onSinkAudioChanged: root.syncFromNative()
    Component.onCompleted: root.syncFromNative()
}
