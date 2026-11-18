import QtQuick
import "AudioReducer.js" as AudioReducer

QtObject {
    id: root

    required property var backend

    readonly property bool available: state.available
    readonly property int volumePercent: state.volumePercent
    readonly property bool muted: state.muted
    readonly property string activeOutputId: state.activeOutputId
    readonly property string activeOutputLabel: state.activeOutputLabel

    readonly property bool sourceAvailable: state.sourceAvailable
    readonly property int sourceVolumePercent: state.sourceVolumePercent
    readonly property bool sourceMuted: state.sourceMuted
    readonly property string activeInputId: state.activeInputId
    readonly property string activeInputLabel: state.activeInputLabel

    readonly property ListModel outputs: ListModel {
        id: outputsModel
    }
    readonly property ListModel inputs: ListModel {
        id: inputsModel
    }
    readonly property bool micCaptureActive: state.micCaptureActive
    readonly property bool cameraCaptureActive: state.cameraCaptureActive
    readonly property bool screenCaptureActive: state.screenCaptureActive
    readonly property string privacySummary: state.privacySummary
    readonly property bool rtpMirrorActive: state.rtpMirrorActive

    function clamp(percent: int): int {
        return Math.max(0, Math.min(100, percent));
    }

    function _syncListModel(targetModel, items): void {
        const list = items || [];
        targetModel.clear();
        for (const item of list)
            targetModel.append(item);
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
        if (backendAvailable) {
            state.activeOutputId = String(root.backend.activeOutputId || "");
            state.activeOutputLabel = String(root.backend.activeOutputLabel || "");
        }

        const srcAvail = backendPresent && root.backend.sourceAvailable === true;
        const nextSrc = AudioReducer.reduce({
            available: state.sourceAvailable,
            volumePercent: state.sourceVolumePercent,
            muted: state.sourceMuted
        }, {
            backendReady: srcAvail,
            targetPresent: backendPresent,
            targetReady: srcAvail,
            controlsPresent: backendPresent,
            volume: srcAvail ? (root.backend.sourceVolumePercent || 0) / 100 : NaN,
            muted: srcAvail ? Boolean(root.backend.sourceMuted) : state.sourceMuted
        });
        state.sourceVolumePercent = nextSrc.volumePercent;
        state.sourceMuted = nextSrc.muted;
        state.sourceAvailable = nextSrc.available;
        if (srcAvail) {
            state.activeInputId = String(root.backend.activeInputId || "");
            state.activeInputLabel = String(root.backend.activeInputLabel || "");
        }

        state.micCaptureActive = backendPresent && root.backend.micCaptureActive === true;
        state.cameraCaptureActive = backendPresent && root.backend.cameraCaptureActive === true;
        state.screenCaptureActive = backendPresent && root.backend.screenCaptureActive === true;
        state.privacySummary = backendPresent ? String(root.backend.privacySummary || "") : "";
        state.rtpMirrorActive = backendPresent && root.backend.rtpMirrorActive === true;

        root._syncListModel(outputsModel, backendPresent ? root.backend.outputsSnapshot : []);
        root._syncListModel(inputsModel, backendPresent ? root.backend.inputsSnapshot : []);
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

    function setSourceVolume(percent: int): void {
        if (!root.sourceAvailable)
            return;
        const clamped = root.clamp(percent);
        state.sourceVolumePercent = clamped;
        if (root.backend && typeof root.backend.setSourceVolume === "function")
            root.backend.setSourceVolume(clamped);
    }

    function adjustSourceVolume(direction: int): void {
        if (direction > 0)
            root.setSourceVolume(root.sourceVolumePercent + 2);
        else if (direction < 0)
            root.setSourceVolume(root.sourceVolumePercent - 2);
    }

    function toggleSourceMute(): void {
        if (!root.sourceAvailable)
            return;
        state.sourceMuted = !state.sourceMuted;
        if (root.backend && typeof root.backend.setSourceMuted === "function")
            root.backend.setSourceMuted(state.sourceMuted);
    }

    function selectOutput(name: string): void {
        if (!name || !root.backend || typeof root.backend.selectOutput !== "function")
            return;
        root.backend.selectOutput(name);
    }

    function selectInput(name: string): void {
        if (!name || !root.backend || typeof root.backend.selectInput !== "function")
            return;
        root.backend.selectInput(name);
    }

    property QtObject state: QtObject {
        property bool available: false
        property int volumePercent: 0
        property bool muted: false
        property string activeOutputId: ""
        property string activeOutputLabel: ""

        property bool sourceAvailable: false
        property int sourceVolumePercent: 0
        property bool sourceMuted: false
        property string activeInputId: ""
        property string activeInputLabel: ""

        property bool micCaptureActive: false
        property bool cameraCaptureActive: false
        property bool screenCaptureActive: false
        property string privacySummary: ""
        property bool rtpMirrorActive: false
    }

    property Connections backendConnections: Connections {
        target: root.backend
        ignoreUnknownSignals: true

        function onAvailableChanged(): void {
            root.reconcile();
        }

        function onVolumePercentChanged(): void {
            root.reconcile();
        }

        function onMutedChanged(): void {
            root.reconcile();
        }

        function onActiveOutputIdChanged(): void {
            root.reconcile();
        }

        function onActiveOutputLabelChanged(): void {
            root.reconcile();
        }

        function onSourceAvailableChanged(): void {
            root.reconcile();
        }

        function onSourceVolumePercentChanged(): void {
            root.reconcile();
        }

        function onSourceMutedChanged(): void {
            root.reconcile();
        }

        function onActiveInputIdChanged(): void {
            root.reconcile();
        }

        function onActiveInputLabelChanged(): void {
            root.reconcile();
        }

        function onOutputsSnapshotChanged(): void {
            root.reconcile();
        }

        function onInputsSnapshotChanged(): void {
            root.reconcile();
        }

        function onMicCaptureActiveChanged(): void {
            root.reconcile();
        }

        function onCameraCaptureActiveChanged(): void {
            root.reconcile();
        }

        function onScreenCaptureActiveChanged(): void {
            root.reconcile();
        }

        function onPrivacySummaryChanged(): void {
            root.reconcile();
        }

        function onRtpMirrorActiveChanged(): void {
            root.reconcile();
        }
    }

    onBackendChanged: root.reconcile()
    Component.onCompleted: root.reconcile()
}
