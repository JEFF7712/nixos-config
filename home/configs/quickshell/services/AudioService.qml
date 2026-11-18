import QtQuick
import Quickshell
import "internal" as Internal

Scope {
    id: root

    readonly property bool available: audioModel.available
    readonly property int volumePercent: audioModel.volumePercent
    readonly property bool muted: audioModel.muted
    readonly property string activeOutputId: audioModel.activeOutputId
    readonly property string activeOutputLabel: audioModel.activeOutputLabel
    readonly property ListModel outputs: audioModel.outputs

    readonly property bool sourceAvailable: audioModel.sourceAvailable
    readonly property int sourceVolumePercent: audioModel.sourceVolumePercent
    readonly property bool sourceMuted: audioModel.sourceMuted
    readonly property string activeInputId: audioModel.activeInputId
    readonly property string activeInputLabel: audioModel.activeInputLabel
    readonly property ListModel inputs: audioModel.inputs

    readonly property bool micCaptureActive: audioModel.micCaptureActive
    readonly property bool cameraCaptureActive: audioModel.cameraCaptureActive
    readonly property bool screenCaptureActive: audioModel.screenCaptureActive
    readonly property string privacySummary: audioModel.privacySummary
    readonly property bool rtpMirrorActive: audioModel.rtpMirrorActive

    function setVolume(percent: int): void {
        audioModel.setVolume(percent);
    }

    function adjustVolume(direction: int): void {
        audioModel.adjustVolume(direction);
    }

    function toggleMute(): void {
        audioModel.toggleMute();
    }

    function selectOutput(name: string): void {
        audioModel.selectOutput(name);
    }

    function setSourceVolume(percent: int): void {
        audioModel.setSourceVolume(percent);
    }

    function adjustSourceVolume(direction: int): void {
        audioModel.adjustSourceVolume(direction);
    }

    function toggleSourceMute(): void {
        audioModel.toggleSourceMute();
    }

    function selectInput(name: string): void {
        audioModel.selectInput(name);
    }

    function openMixer(): void {
        Quickshell.execDetached(["pavucontrol"]);
    }

    Internal.PipewireAudioBackend {
        id: pipewireBackend
    }

    Internal.AudioModel {
        id: audioModel
        backend: pipewireBackend
    }
}
