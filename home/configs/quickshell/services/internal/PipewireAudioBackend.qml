import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "AudioReducer.js" as AudioReducer

Scope {
    id: root

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

    readonly property var outputsSnapshot: state.outputsSnapshot
    readonly property var inputsSnapshot: state.inputsSnapshot
    readonly property bool micCaptureActive: state.micCaptureActive
    readonly property bool cameraCaptureActive: state.cameraCaptureActive
    readonly property bool screenCaptureActive: state.screenCaptureActive
    readonly property string privacySummary: state.privacySummary
    readonly property bool rtpMirrorActive: state.rtpMirrorActive

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: root.sink ? root.sink.audio : null
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sourceAudio: root.source ? root.source.audio : null

    readonly property var trackedObjects: {
        const list = [];
        if (root.sink)
            list.push(root.sink);
        if (root.source)
            list.push(root.source);
        const nodes = (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : [];
        for (const n of nodes) {
            if (n)
                list.push(n);
        }
        return list;
    }

    function syncFromNative(): void {
        const sinkPresent = root.sink !== null && root.sink !== undefined;
        const audioPresent = root.sinkAudio !== null && root.sinkAudio !== undefined;
        const volume = audioPresent ? root.sinkAudio.volume : NaN;
        const valid = Pipewire.ready && sinkPresent && root.sink.ready && audioPresent && typeof volume === "number" && isFinite(volume);

        if (!valid) {
            state.available = false;
        } else {
            state.volumePercent = Math.max(0, Math.min(100, Math.round(volume * 100)));
            state.muted = Boolean(root.sinkAudio.muted);
            state.activeOutputId = String(root.sink.name || "");
            state.activeOutputLabel = AudioReducer.formatNodeLabel(root.sink.name, root.sink.description, root.sink.nickname);
            state.available = true;
        }

        const sourcePresent = root.source !== null && root.source !== undefined;
        const srcAudioPresent = root.sourceAudio !== null && root.sourceAudio !== undefined;
        const srcVolume = srcAudioPresent ? root.sourceAudio.volume : NaN;
        const srcValid = Pipewire.ready && sourcePresent && root.source.ready && srcAudioPresent && typeof srcVolume === "number" && isFinite(srcVolume);

        if (!srcValid) {
            state.sourceAvailable = false;
        } else {
            state.sourceVolumePercent = Math.max(0, Math.min(100, Math.round(srcVolume * 100)));
            state.sourceMuted = Boolean(root.sourceAudio.muted);
            state.activeInputId = String(root.source.name || "");
            state.activeInputLabel = AudioReducer.formatNodeLabel(root.source.name, root.source.description, root.source.nickname);
            state.sourceAvailable = true;
        }

        root.syncGraph();
    }

    function syncGraph(): void {
        if (!Pipewire.ready)
            return;

        const rawNodes = (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : [];
        const rawLinks = (Pipewire.links && Pipewire.links.values) ? Pipewire.links.values : [];

        const sinkEntries = [];
        const sourceEntries = [];
        const nodeSnapshots = [];

        for (const n of rawNodes) {
            if (!n || !n.name)
                continue;
            const props = n.properties || {};
            const mediaClass = String(props["media.class"] || "");
            const iconName = String(props["device.icon_name"] || props["device.icon-name"] || "");

            nodeSnapshots.push({
                id: n.id,
                name: String(n.name),
                mediaClass: mediaClass,
                mediaRole: String(props["media.role"] || ""),
                isStream: n.isStream === true,
                captureSink: String(props["stream.capture.sink"] || "") === "true",
                bluezLoopback: String(props["bluez5.loopback"] || "") === "true"
            });

            if (n.ready && !n.isStream && n.audio) {
                if (n.isSink && mediaClass === "Audio/Sink") {
                    sinkEntries.push({
                        id: n.id,
                        name: String(n.name),
                        description: String(n.description || props["node.description"] || ""),
                        nickname: String(n.nickname || props["node.nick"] || ""),
                        iconName: iconName
                    });
                } else if (!n.isSink && mediaClass === "Audio/Source" && String(props["bluez5.loopback"] || "") !== "true") {
                    sourceEntries.push({
                        id: n.id,
                        name: String(n.name),
                        description: String(n.description || props["node.description"] || ""),
                        nickname: String(n.nickname || props["node.nick"] || ""),
                        iconName: iconName
                    });
                }
            }
        }

        const linkSnapshots = [];
        for (const l of rawLinks) {
            if (!l || !l.source || !l.target)
                continue;
            linkSnapshots.push({
                source: String(l.source.name || ""),
                target: String(l.target.name || "")
            });
        }

        state.outputsSnapshot = AudioReducer.buildDeviceList(sinkEntries, state.activeOutputId);
        state.inputsSnapshot = AudioReducer.buildDeviceList(sourceEntries, state.activeInputId);

        const telemetry = AudioReducer.detectPrivacyAndRtp(nodeSnapshots, linkSnapshots);
        state.micCaptureActive = telemetry.micCaptureActive;
        state.cameraCaptureActive = telemetry.cameraCaptureActive;
        state.screenCaptureActive = telemetry.screenCaptureActive;
        state.privacySummary = telemetry.privacySummary;
        state.rtpMirrorActive = telemetry.rtpMirrorActive;
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

    function setSourceVolume(percent: int): void {
        if (!root.sourceAvailable || root.sourceAudio === null || root.sourceAudio === undefined)
            return;
        root.sourceAudio.volume = Math.max(0, Math.min(100, percent)) / 100;
    }

    function setSourceMuted(value: bool): void {
        if (!root.sourceAvailable || root.sourceAudio === null || root.sourceAudio === undefined)
            return;
        root.sourceAudio.muted = value;
    }

    function selectOutput(name: string): void {
        if (!name || !Pipewire.ready || !Pipewire.nodes)
            return;
        const nodes = Pipewire.nodes.values || [];
        for (const n of nodes) {
            if (n && n.isSink && !n.isStream && n.name === name) {
                Pipewire.preferredDefaultAudioSink = n;
                return;
            }
        }
    }

    function selectInput(name: string): void {
        if (!name || !Pipewire.ready || !Pipewire.nodes)
            return;
        const nodes = Pipewire.nodes.values || [];
        for (const n of nodes) {
            if (n && !n.isSink && !n.isStream && n.name === name) {
                Pipewire.preferredDefaultAudioSource = n;
                return;
            }
        }
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

        property var outputsSnapshot: []
        property var inputsSnapshot: []
        property bool micCaptureActive: false
        property bool cameraCaptureActive: false
        property bool screenCaptureActive: false
        property string privacySummary: ""
        property bool rtpMirrorActive: false
    }

    PwObjectTracker {
        objects: root.trackedObjects
    }

    Connections {
        target: Pipewire

        function onReadyChanged(): void {
            root.syncFromNative();
        }

        function onDefaultAudioSinkChanged(): void {
            root.syncFromNative();
        }

        function onDefaultAudioSourceChanged(): void {
            root.syncFromNative();
        }
    }

    Connections {
        target: Pipewire.nodes

        function onValuesChanged(): void {
            root.syncGraph();
        }
    }

    Connections {
        target: Pipewire.links

        function onValuesChanged(): void {
            root.syncGraph();
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

    Connections {
        target: root.source

        function onReadyChanged(): void {
            root.syncFromNative();
        }
    }

    Connections {
        target: root.sourceAudio

        function onVolumesChanged(): void {
            root.syncFromNative();
        }

        function onMutedChanged(): void {
            root.syncFromNative();
        }
    }

    onSinkChanged: root.syncFromNative()
    onSinkAudioChanged: root.syncFromNative()
    onSourceChanged: root.syncFromNative()
    onSourceAudioChanged: root.syncFromNative()
    Component.onCompleted: root.syncFromNative()
}
