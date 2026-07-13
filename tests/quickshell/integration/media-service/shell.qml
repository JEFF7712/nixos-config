import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: root

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""
    property int phase: 0
    property double phaseStarted: 0
    property var policy: ({})
    property var stableState: ({})
    property int offBaseline: 0
    property int monitoringBaseline: 0
    property double monitoringEnabledAt: 0
    property int stoppedBaseline: 0
    property int followBaseline: 0
    property real interpolationStart: 0
    property bool malformedPreserved: false
    property bool disappearancePreserved: false
    property bool recoveryPassed: false
    property bool cadencePassed: false
    property bool followCoalesced: false
    property bool bareDefaultPassed: false
    property bool immediatePollPassed: false
    property bool noDuplicateEnablePassed: false
    property bool periodicPollPassed: false
    property bool interpolationPassed: false
    property bool followRestartPassed: false
    property bool pendingInvalidationPassed: false
    property bool queuedInvalidationPassed: false
    property bool actionOrderPassed: false
    property bool delayedActionPassed: false
    property QtObject consumerOne: QtObject { property var service: mediaService }
    property QtObject consumerTwo: QtObject { property var service: mediaService }

    Services.AudioService {
        id: audioService
    }

    Services.MediaService {
        id: mediaService
        audioService: audioService
    }

    function now(): double {
        return Date.now();
    }

    function scalarState(): var {
        return {
            status: mediaService.status,
            title: mediaService.title,
            artist: mediaService.artist,
            album: mediaService.album,
            artUrl: mediaService.artUrl,
            position: mediaService.positionSeconds,
            length: mediaService.lengthSeconds,
            volume: mediaService.effectiveVolume,
            shuffle: mediaService.shuffleEnabled,
            loop: mediaService.loopMode,
            volumeIsPlayer: mediaService.volumeIsPlayer
        };
    }

    function sameScalars(left, right): bool {
        return JSON.stringify(left) === JSON.stringify(right);
    }

    function positionCallCount(): int {
        callsFile.reload();
        callsFile.waitForJob();
        const lines = callsFile.text().split("\n");
        let count = 0;
        for (const line of lines) {
            if (line.trim() === "position")
                count++;
        }
        return count;
    }

    function requestSnapshot(): void {
        mediaService.detailedMonitoring = true;
        snapshotPulse.restart();
    }

    function writePlayer(state): void {
        playerFile.setText(JSON.stringify(state) + "\n");
    }

    function finish(passed, error): void {
        resultFile.setText(JSON.stringify({
            passed: passed,
            error: error || "",
            phase: root.phase,
            sharedIdentity: root.consumerOne.service === root.consumerTwo.service,
            policyPassed: root.bareDefaultPassed && root.recoveryPassed,
            malformedPreserved: root.malformedPreserved,
            disappearancePreserved: root.disappearancePreserved,
            recoveryPassed: root.recoveryPassed,
            cadencePassed: root.cadencePassed,
            followCoalesced: root.followCoalesced,
            bareDefaultPassed: root.bareDefaultPassed,
            immediatePollPassed: root.immediatePollPassed,
            noDuplicateEnablePassed: root.noDuplicateEnablePassed,
            periodicPollPassed: root.periodicPollPassed,
            interpolationPassed: root.interpolationPassed,
            followRestartPassed: root.followRestartPassed,
            pendingInvalidationPassed: root.pendingInvalidationPassed,
            queuedInvalidationPassed: root.queuedInvalidationPassed,
            actionOrderPassed: root.actionOrderPassed,
            delayedActionPassed: root.delayedActionPassed,
            diagnostics: root.scalarState()
        }) + "\n");
        Qt.quit();
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
        id: policyFile
        path: root.stateDir + "/policy.json"
        blockLoading: true
    }

    FileView {
        id: playerFile
        path: root.stateDir + "/player.json"
        blockWrites: true
        atomicWrites: true
    }

    FileView {
        id: malformedFile
        path: root.stateDir + "/malformed-snapshot.once"
        blockWrites: true
    }

    FileView {
        id: callsFile
        path: root.stateDir + "/playerctl-calls.log"
        blockLoading: true
    }

    FileView {
        id: followFifo
        path: root.stateDir + "/follow.fifo"
        blockWrites: false
        atomicWrites: false
    }

    FileView {
        id: followExitFile
        path: root.stateDir + "/follow-exit.once"
        blockWrites: true
    }

    FileView {
        id: slowSnapshotFile
        path: root.stateDir + "/slow-snapshot.once"
        blockWrites: true
    }

    FileView {
        id: slowActionFile
        path: root.stateDir + "/slow-action.once"
        blockWrites: true
    }

    FileView {
        id: suppressActionNotifyFile
        path: root.stateDir + "/suppress-action-notify.count"
        blockWrites: true
    }

    FileView {
        id: lifecycleFile
        path: root.stateDir + "/playerctl-lifecycle.log"
        blockLoading: true
    }

    FileView {
        id: delayedActionFile
        path: root.stateDir + "/delayed-play-pause.once"
        blockWrites: true
    }

    function followStartCount(): int {
        lifecycleFile.reload();
        lifecycleFile.waitForJob();
        return lifecycleFile.text().split("\n").filter(line => line.startsWith("start ")).length;
    }

    Component.onCompleted: {
        root.policy = JSON.parse(policyFile.text());
        root.phaseStarted = root.now();
        readyFile.setText("ready\n");
    }

    Timer {
        id: snapshotPulse
        interval: 10
        repeat: false
        onTriggered: mediaService.detailedMonitoring = false
    }

    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            const elapsed = root.now() - root.phaseStarted;
            const oneExpected = root.policy.scenarios.onePlayer.expected;
            const multiExpected = root.policy.scenarios.multipleDefaultPaused.expected;
            const recoveryExpected = root.policy.scenarios.recovery.expected;

            if (root.phase === 0 && mediaService.available
                    && mediaService.title === oneExpected.title && mediaService.status === oneExpected.status) {
                if (root.consumerOne.service !== root.consumerTwo.service)
                    return root.finish(false, "consumers do not share service identity");
                mediaService.togglePlaying();
                mediaService.toggleShuffle();
                mediaService.cycleLoop();
                mediaService.setEffectiveVolume(0.42);
                mediaService.seek(25);
                mediaService.previous();
                mediaService.next();
                root.phase = 1;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 1 && mediaService.status === "Paused" && mediaService.shuffleEnabled
                    && mediaService.loopMode === "Playlist" && Math.abs(mediaService.effectiveVolume - 0.42) < 0.001
                    && Math.abs(mediaService.positionSeconds - 25) < 0.01) {
                root.stableState = root.scalarState();
                malformedFile.setText("malformed\n");
                root.requestSnapshot();
                root.phase = 2;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 2 && elapsed >= 500) {
                root.malformedPreserved = mediaService.available && root.sameScalars(root.stableState, root.scalarState());
                if (!root.malformedPreserved)
                    return root.finish(false, "malformed snapshot changed the last complete state");
                root.writePlayer(root.policy.scenarios.disappearance.state);
                root.requestSnapshot();
                root.phase = 3;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 3 && !mediaService.available) {
                root.disappearancePreserved = root.sameScalars(root.stableState, root.scalarState());
                if (!root.disappearancePreserved)
                    return root.finish(false, "player disappearance discarded last complete scalar state");
                root.writePlayer(root.policy.scenarios.multipleDefaultPaused.state);
                root.requestSnapshot();
                root.phase = 4;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 4 && mediaService.available && mediaService.title === multiExpected.title
                    && mediaService.status === multiExpected.status) {
                root.bareDefaultPassed = true;
                mediaService.togglePlaying();
                root.phase = 5;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 5 && mediaService.title === multiExpected.title && mediaService.status === "Playing") {
                root.writePlayer(root.policy.scenarios.recovery.state);
                root.requestSnapshot();
                root.phase = 6;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 6 && mediaService.available && mediaService.title === recoveryExpected.title
                    && mediaService.status === recoveryExpected.status) {
                root.recoveryPassed = true;
                mediaService.detailedMonitoring = false;
                root.phase = 7;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 7 && elapsed >= 400) {
                root.offBaseline = root.positionCallCount();
                root.phase = 8;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 8 && elapsed >= 1700) {
                if (root.positionCallCount() !== root.offBaseline)
                    return root.finish(false, "detailedMonitoring false produced periodic snapshots");
                root.monitoringBaseline = root.positionCallCount();
                root.monitoringEnabledAt = root.now();
                mediaService.detailedMonitoring = true;
                root.phase = 9;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 9 && root.positionCallCount() >= root.monitoringBaseline + 1) {
                root.immediatePollPassed = elapsed < 700;
                root.interpolationStart = mediaService.positionSeconds;
                root.phase = 10;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 10 && elapsed >= 700) {
                root.noDuplicateEnablePassed = root.positionCallCount() === root.monitoringBaseline + 1;
                if (!root.noDuplicateEnablePassed)
                    return root.finish(false, "detailed monitoring enable produced a duplicate refresh before 1500ms");
                root.interpolationPassed = mediaService.positionSeconds >= root.interpolationStart + 0.5;
                root.phase = 11;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 11 && root.positionCallCount() >= root.monitoringBaseline + 2) {
                root.periodicPollPassed = root.now() - root.monitoringEnabledAt >= 1400;
                if (!root.periodicPollPassed)
                    return root.finish(false, "second monitoring snapshot occurred before the 1500ms poll window");
                mediaService.detailedMonitoring = false;
                root.phase = 12;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 12 && elapsed >= 250) {
                root.stoppedBaseline = root.positionCallCount();
                root.phase = 13;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 13 && elapsed >= 1700) {
                root.cadencePassed = root.immediatePollPassed && root.periodicPollPassed
                    && root.interpolationPassed && root.positionCallCount() === root.stoppedBaseline;
                if (!root.cadencePassed)
                    return root.finish(false, "detailed monitoring cadence or interpolation failed");
                const followed = root.policy.scenarios.recovery.state;
                followed.title = "Follow coalesced update";
                root.writePlayer(followed);
                root.followBaseline = root.positionCallCount();
                followFifo.setText("event-one\nevent-two\nevent-three\n");
                root.phase = 14;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 14 && mediaService.title === "Follow coalesced update" && elapsed >= 450) {
                root.followCoalesced = root.positionCallCount() === root.followBaseline + 1;
                if (!root.followCoalesced)
                    return root.finish(false, "follow records did not debounce to one snapshot");
                followExitFile.setText("exit\n");
                followFifo.setText("force-exit\n");
                root.phase = 15;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 15 && root.followStartCount() >= 2 && elapsed >= 600) {
                root.followRestartPassed = root.followStartCount() === 2;
                if (!root.followRestartPassed)
                    return root.finish(false, "follow process restart was missing or duplicated");
                root.followBaseline = root.positionCallCount();
                slowSnapshotFile.setText("0.6\n");
                root.requestSnapshot();
                root.phase = 16;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 16 && elapsed >= 150) {
                const pending = root.policy.scenarios.recovery.state;
                pending.title = "Pending invalidation update";
                root.writePlayer(pending);
                followFifo.setText("during-snapshot-one\nduring-snapshot-two\n");
                root.phase = 17;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 17 && elapsed >= 1300 && mediaService.title === "Pending invalidation update") {
                root.pendingInvalidationPassed = root.positionCallCount() === root.followBaseline + 2;
                if (!root.pendingInvalidationPassed)
                    return root.finish(false, "in-flight invalidation was lost or produced more than one follow-up snapshot");
                root.followBaseline = root.positionCallCount();
                slowActionFile.setText("0.7\n");
                suppressActionNotifyFile.setText("1\n");
                mediaService.togglePlaying();
                root.phase = 18;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 18 && elapsed >= 200) {
                const queued = root.policy.scenarios.recovery.state;
                queued.title = "Queued invalidation update";
                root.writePlayer(queued);
                followFifo.setText("while-snapshot-queued\n");
                root.phase = 19;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 19 && elapsed >= 1300 && mediaService.title === "Queued invalidation update") {
                root.queuedInvalidationPassed = root.positionCallCount() === root.followBaseline + 1;
                if (!root.queuedInvalidationPassed)
                    return root.finish(false, "queued snapshot incorrectly scheduled a redundant follow-up");
                root.followBaseline = root.positionCallCount();
                slowActionFile.setText("1.5\n");
                suppressActionNotifyFile.setText("2\n");
                mediaService.previous();
                root.phase = 20;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 20 && elapsed >= 50) {
                root.requestSnapshot();
                followFifo.setText("queue-between-actions\n");
                root.phase = 21;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 21 && elapsed >= 500) {
                mediaService.togglePlaying();
                root.phase = 22;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 22 && elapsed >= 2400) {
                root.actionOrderPassed = mediaService.status === "Playing"
                    && root.positionCallCount() === root.followBaseline + 2;
                if (!root.actionOrderPassed)
                    return root.finish(false, "A,S,B ordering did not reconcile exactly once after action B");
                root.followBaseline = root.positionCallCount();
                delayedActionFile.setText("0.08\n");
                mediaService.togglePlaying();
                root.phase = 23;
                root.phaseStarted = root.now();
                return;
            }

            if (root.phase === 23 && elapsed >= 700) {
                root.delayedActionPassed = mediaService.status === "Paused"
                    && root.positionCallCount() === root.followBaseline + 1;
                if (!root.delayedActionPassed)
                    return root.finish(false, "delayed action settlement did not coalesce to one final snapshot");
                root.finish(true, "");
            }
        }
    }

    Timer {
        interval: 25000
        running: true
        repeat: false
        onTriggered: root.finish(false, "media fixture timed out")
    }
}
