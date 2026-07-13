import QtQuick
import Quickshell
import "internal" as Internal

Scope {
    id: root

    required property AudioService audioService
    property bool detailedMonitoring: false

    readonly property bool available: model.available
    readonly property bool playing: model.playing
    readonly property string status: model.status
    readonly property string title: model.title
    readonly property string artist: model.artist
    readonly property string album: model.album
    readonly property string artUrl: model.artUrl
    readonly property real positionSeconds: model.positionSeconds
    readonly property real lengthSeconds: model.lengthSeconds
    readonly property real effectiveVolume: model.effectiveVolume
    readonly property bool shuffleEnabled: model.shuffleEnabled
    readonly property bool volumeIsPlayer: model.volumeIsPlayer
    readonly property string loopMode: model.loopMode
    readonly property bool canSeek: model.canSeek
    readonly property bool canTogglePlaying: model.canTogglePlaying
    readonly property bool canGoNext: model.canGoNext
    readonly property bool canGoPrevious: model.canGoPrevious
    readonly property bool canShuffle: model.canShuffle
    readonly property bool canLoop: model.canLoop
    readonly property bool canSetPlayerVolume: model.canSetPlayerVolume

    function togglePlaying(): void { model.togglePlaying(); }
    function next(): void { model.next(); }
    function previous(): void { model.previous(); }
    function seek(seconds: real): void { model.seek(seconds); }
    function toggleShuffle(): void { model.toggleShuffle(); }
    function cycleLoop(): void { model.cycleLoop(); }
    function setEffectiveVolume(value: real): void { model.setEffectiveVolume(value); }

    Internal.MediaModel {
        id: model
        audioService: root.audioService
        detailedMonitoring: root.detailedMonitoring
    }
}
