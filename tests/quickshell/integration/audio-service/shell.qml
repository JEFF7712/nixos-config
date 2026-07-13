import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: root

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""
    property bool eventObserved: false
    property bool initialReady: false
    property bool unavailableObserved: false

    function fail(message) {
        resultFile.setText(JSON.stringify({passed: false, diagnostics: {error: message}}) + "\n");
        Qt.quit();
    }

    function beginGestures() {
        consumerOne.setVolume(150);
        consumerTwo.adjustVolume(-1);
        consumerOne.adjustVolume(1);
        consumerTwo.toggleMute();
        consumerOne.openMixer();
        resultTimer.start();
    }

    Services.AudioService {
        id: audioService
    }

    component ProbeConsumer: QtObject {
        required property Services.AudioService audioService
        property int volumeUpdates: 0
        property int muteUpdates: 0
        property int seenVolume: audioService.volumePercent
        property bool seenMuted: audioService.muted

        function setVolume(percent) { audioService.setVolume(percent); }
        function adjustVolume(direction) { audioService.adjustVolume(direction); }
        function toggleMute() { audioService.toggleMute(); }
        function openMixer() { audioService.openMixer(); }

        property Connections serviceConnections: Connections {
            target: audioService
            function onVolumePercentChanged() {
                seenVolume = audioService.volumePercent;
                volumeUpdates++;
                eventCheck.restart();
            }
            function onMutedChanged() {
                seenMuted = audioService.muted;
                muteUpdates++;
                eventCheck.restart();
            }
        }
    }

    ProbeConsumer {
        id: consumerOne
        audioService: audioService
    }

    ProbeConsumer {
        id: consumerTwo
        audioService: audioService
    }

    function checkExternalEvent() {
        if (!unavailableObserved || !audioService.available || eventObserved
                || consumerOne.seenVolume !== 63 || consumerTwo.seenVolume !== 63
                || !consumerOne.seenMuted || !consumerTwo.seenMuted)
            return;
        eventObserved = true;
        if (consumerOne.volumeUpdates !== 1 || consumerTwo.volumeUpdates !== 1
                || consumerOne.muteUpdates !== 1 || consumerTwo.muteUpdates !== 1) {
            fail("external event counts: " + consumerOne.volumeUpdates + "," + consumerTwo.volumeUpdates
                + "," + consumerOne.muteUpdates + "," + consumerTwo.muteUpdates);
            return;
        }
        beginGestures();
    }

    Connections {
        target: audioService
        function onAvailableChanged() {
            if (audioService.available && !root.initialReady) {
                root.initialReady = true;
                consumerOne.volumeUpdates = 0;
                consumerTwo.volumeUpdates = 0;
                consumerOne.muteUpdates = 0;
                consumerTwo.muteUpdates = 0;
                readyFile.setText("ready\n");
                return;
            }
            if (!audioService.available && root.initialReady && !root.unavailableObserved) {
                if (audioService.volumePercent !== 40 || audioService.muted) {
                    root.fail("unavailable probe discarded the last valid audio state");
                    return;
                }
                root.unavailableObserved = true;
                unavailableFile.setText("unavailable\n");
                return;
            }
            if (audioService.available && root.unavailableObserved)
                eventCheck.restart();
        }
    }

    FileView {
        id: readyFile
        path: root.stateDir + "/ready"
        blockWrites: true
    }

    FileView {
        id: resultFile
        path: root.stateDir + "/result.json"
        blockWrites: true
    }

    FileView {
        id: unavailableFile
        path: root.stateDir + "/unavailable"
        blockWrites: true
    }

    Timer {
        id: eventCheck
        interval: 1
        repeat: false
        onTriggered: root.checkExternalEvent()
    }

    Timer {
        id: resultTimer
        interval: 900
        repeat: false
        onTriggered: {
            const passed = audioService.available
                && audioService.volumePercent === 77
                && audioService.muted === false;
            resultFile.setText(JSON.stringify({
                passed: passed,
                diagnostics: {
                    sharedObject: consumerOne.audioService === consumerTwo.audioService,
                    volumePercent: audioService.volumePercent,
                    muted: audioService.muted,
                    consumerOneVolumeUpdates: consumerOne.volumeUpdates,
                    consumerTwoVolumeUpdates: consumerTwo.volumeUpdates
                }
            }) + "\n");
            Qt.quit();
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: false
        onTriggered: root.fail("audio-service fixture timed out")
    }
}
