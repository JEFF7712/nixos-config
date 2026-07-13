import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property bool available: root.hasValidState
    readonly property int volumePercent: root.currentVolumePercent
    readonly property bool muted: root.currentMuted

    property bool hasValidState: false
    property int currentVolumePercent: 0
    property bool currentMuted: false
    property bool probePending: false
    property int commandGeneration: 0
    property int probeGeneration: 0
    property bool probeOutputValid: false
    property int probeVolumePercent: 0
    property bool probeMuted: false
    property var commandQueue: []

    function clamp(percent: int): int {
        return Math.max(0, Math.min(100, percent));
    }

    function setVolume(percent: int): void {
        const clamped = root.clamp(percent);
        root.currentVolumePercent = clamped;
        root.enqueueCommand(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", clamped + "%"]);
    }

    function adjustVolume(direction: int): void {
        if (direction > 0)
            root.setVolume(root.currentVolumePercent + 2);
        else if (direction < 0)
            root.setVolume(root.currentVolumePercent - 2);
    }

    function toggleMute(): void {
        root.currentMuted = !root.currentMuted;
        root.enqueueCommand(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
    }

    function openMixer(): void {
        Quickshell.execDetached(["pavucontrol"]);
    }

    function enqueueCommand(command: var): void {
        root.commandGeneration++;
        root.commandQueue = root.commandQueue.concat([command]);
        root.advanceWpctl();
    }

    function advanceWpctl(): void {
        if (commandProcess.running || probeProcess.running)
            return;
        if (root.commandQueue.length > 0) {
            commandProcess.command = root.commandQueue[0];
            root.commandQueue = root.commandQueue.slice(1);
            commandProcess.running = true;
            return;
        }
        if (root.probePending) {
            root.probePending = false;
            root.probeGeneration = root.commandGeneration;
            root.probeOutputValid = false;
            probeProcess.running = true;
        }
    }

    function requestProbe(): void {
        root.probePending = true;
        root.advanceWpctl();
    }

    Process {
        id: probeProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.trim().match(/^Volume:\s+([0-9]+(?:\.[0-9]+)?)(?:\s+\[MUTED\])?$/);
                if (!match)
                    return;
                const parsed = Math.round(parseFloat(match[1]) * 100);
                if (isNaN(parsed))
                    return;
                root.probeVolumePercent = root.clamp(parsed);
                root.probeMuted = this.text.indexOf("[MUTED]") !== -1;
                root.probeOutputValid = true;
            }
        }
        onExited: (exitCode, exitStatus) => {
            const isCurrent = root.probeGeneration === root.commandGeneration
                && !commandProcess.running && root.commandQueue.length === 0;
            if (isCurrent) {
                const valid = exitCode === 0 && exitStatus === 0 && root.probeOutputValid;
                if (valid) {
                    root.currentVolumePercent = root.probeVolumePercent;
                    root.currentMuted = root.probeMuted;
                }
                root.hasValidState = valid;
            }
            Qt.callLater(root.advanceWpctl);
        }
    }

    Process {
        id: commandProcess
        onExited: {
            root.probePending = true;
            Qt.callLater(root.advanceWpctl);
        }
    }

    Timer {
        interval: 1
        running: true
        repeat: false
        onTriggered: root.requestProbe()
    }

    Timer {
        id: probeDebounce
        interval: 50
        repeat: false
        onTriggered: root.requestProbe()
    }

    Process {
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "--", "stdbuf", "-oL", "pw-mon"]
        stdout: SplitParser {
            onRead: data => {
                if (data.indexOf("Props:volume") !== -1 || data.indexOf("Props:mute") !== -1
                        || data.indexOf("Props:channelVolumes") !== -1)
                    probeDebounce.restart();
            }
        }
    }
}
