import QtQuick
import Quickshell
import "internal" as Internal

Scope {
    id: root

    readonly property bool available: audioModel.available
    readonly property int volumePercent: audioModel.volumePercent
    readonly property bool muted: audioModel.muted

    function setVolume(percent: int): void {
        audioModel.setVolume(percent);
    }

    function adjustVolume(direction: int): void {
        audioModel.adjustVolume(direction);
    }

    function toggleMute(): void {
        audioModel.toggleMute();
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
