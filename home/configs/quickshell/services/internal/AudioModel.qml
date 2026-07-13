import QtQuick
import "AudioReducer.js" as AudioReducer

QtObject {
    id: root

    required property var backend

    readonly property bool available: state.available
    readonly property int volumePercent: state.volumePercent
    readonly property bool muted: state.muted

    function clamp(percent: int): int {
        return Math.max(0, Math.min(100, percent));
    }

    function reconcile(): void {
        const backendPresent = root.backend !== null && root.backend !== undefined;
        const backendAvailable = backendPresent && root.backend.available === true;
        const next = AudioReducer.reduce({
            available: state.available,
            volumePercent: state.volumePercent,
            muted: state.muted
        }, {
            backendReady: backendAvailable,
            targetPresent: backendPresent,
            targetReady: backendAvailable,
            controlsPresent: backendPresent,
            volume: backendPresent ? root.backend.volumePercent / 100 : NaN,
            muted: backendPresent ? root.backend.muted : state.muted
        });
        state.volumePercent = next.volumePercent;
        state.muted = next.muted;
        state.available = next.available;
    }

    function setVolume(percent: int): void {
        if (!root.available)
            return;
        const clamped = root.clamp(percent);
        state.volumePercent = clamped;
        root.backend.setVolume(clamped);
    }

    function adjustVolume(direction: int): void {
        if (direction > 0)
            root.setVolume(root.volumePercent + 2);
        else if (direction < 0)
            root.setVolume(root.volumePercent - 2);
    }

    function toggleMute(): void {
        if (!root.available)
            return;
        state.muted = !state.muted;
        root.backend.setMuted(state.muted);
    }

    property QtObject state: QtObject {
        property bool available: false
        property int volumePercent: 0
        property bool muted: false
    }

    property Connections backendConnections: Connections {
        target: root.backend

        function onAvailableChanged(): void {
            root.reconcile();
        }

        function onVolumePercentChanged(): void {
            root.reconcile();
        }

        function onMutedChanged(): void {
            root.reconcile();
        }
    }

    onBackendChanged: root.reconcile()
    Component.onCompleted: root.reconcile()
}
