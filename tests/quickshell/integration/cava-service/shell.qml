import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: root

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""
    property string testMode: Quickshell.env("QS_TEST_MODE") || "normal"
    property int phase: 0
    property bool writeStarted: false
    property bool initialDemandPassed: false
    property bool parsingPassed: false
    property bool retryPassed: false
    property bool recoveryPassed: false
    property bool stopPassed: false
    property bool restartPassed: false
    property bool rapidDemandPassed: false
    property bool canceledDemandPassed: false
    property int cancelCheckTick: 0
    property double failedStartAt: 0
    property bool failedStartRecoveryPassed: false
    property bool failedStartCancelPassed: false

    Services.CavaService {
        id: cavaService
        playing: true
        requested: false
    }

    function lifecycle(): string {
        lifecycleFile.reload();
        lifecycleFile.waitForJob();
        return lifecycleFile.text();
    }

    function starts(): int {
        const matches = lifecycle().match(/^start /gm);
        return matches ? matches.length : 0;
    }

    function write(commands): void {
        const argv = ["cava", "--fixture-write"];
        for (const command of commands)
            argv.push(command);
        Quickshell.execDetached(argv);
    }

    function sameValues(expected): bool {
        return JSON.stringify(cavaService.values) === JSON.stringify(expected);
    }

    function finish(passed, error): void {
        resultFile.setText(JSON.stringify({
            passed: passed,
            error: error,
            initialDemandPassed: initialDemandPassed,
            parsingPassed: parsingPassed,
            retryPassed: retryPassed,
            recoveryPassed: recoveryPassed,
            stopPassed: stopPassed,
            restartPassed: restartPassed,
            rapidDemandPassed: rapidDemandPassed,
            canceledDemandPassed: canceledDemandPassed,
            failedStartRecoveryPassed: failedStartRecoveryPassed,
            failedStartCancelPassed: failedStartCancelPassed,
            values: cavaService.values,
            starts: starts()
        }) + "\n");
        Qt.quit();
    }

    FileView {
        id: lifecycleFile
        path: root.stateDir + "/cava-lifecycle.log"
        blockAllReads: true
        printErrors: false
    }

    FileView {
        id: resultFile
        path: root.stateDir + "/result.json"
        blockWrites: true
    }

    FileView {
        id: autoCrashTwo
        path: root.stateDir + "/auto-crash.2"
        blockWrites: true
    }

    FileView {
        id: autoCrashThree
        path: root.stateDir + "/auto-crash.3"
        blockWrites: true
    }

    FileView {
        id: delayTermSix
        path: root.stateDir + "/delay-term.6"
        blockWrites: true
    }

    FileView {
        id: releaseTermSix
        path: root.stateDir + "/release-term.6"
        blockWrites: true
    }

    FileView {
        id: delayTermSeven
        path: root.stateDir + "/delay-term.7"
        blockWrites: true
    }

    FileView {
        id: releaseTermSeven
        path: root.stateDir + "/release-term.7"
        blockWrites: true
    }

    Timer {
        id: driver
        interval: 25
        repeat: true
        running: true
        property int ticks: 0
        onTriggered: {
            ticks++;
            if (ticks > 500) {
                root.finish(false, "fixture timeout at phase " + root.phase);
                return;
            }

            if (root.testMode === "destruction") {
                if (root.starts() === 1)
                    readyFile.setText("ready\n");
                return;
            }

            if (root.testMode === "failed-start-destruction") {
                if (root.phase === 0 && ticks >= 4) {
                    readyFile.setText("destroy-before-retry\n");
                    root.phase = 1;
                }
                return;
            }

            if (root.testMode === "failed-start") {
                if (root.phase === 0 && ticks >= 4) {
                    readyFile.setText("restore-setpriv\n");
                    root.phase = 1;
                } else if (root.phase === 1 && root.starts() === 1) {
                    const fields = root.lifecycle().trim().split("\n")[0].split(" ");
                    root.failedStartRecoveryPassed = Number(fields[3]) - root.failedStartAt >= 200;
                    root.write(["line:8;7"]);
                    root.phase = 2;
                } else if (root.phase === 2 && root.sameValues([8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])) {
                    root.cancelCheckTick = ticks;
                    root.phase = 3;
                } else if (root.phase === 3 && ticks - root.cancelCheckTick >= 50) {
                    root.failedStartRecoveryPassed = root.failedStartRecoveryPassed && root.starts() === 1;
                    cavaService.requested = false;
                    root.phase = 4;
                } else if (root.phase === 4 && root.lifecycle().includes("exit 1 ")) {
                    root.finish(root.failedStartRecoveryPassed, "");
                }
                return;
            }

            if (root.testMode === "failed-start-cancel") {
                if (root.phase === 0 && ticks >= 4) {
                    cavaService.requested = false;
                    root.cancelCheckTick = ticks;
                    root.phase = 1;
                } else if (root.phase === 1 && ticks - root.cancelCheckTick >= 50) {
                    root.failedStartCancelPassed = root.starts() === 0 && root.sameValues([]);
                    root.finish(root.failedStartCancelPassed, "");
                }
                return;
            }

            if (root.phase === 0 && ticks >= 8) {
                root.initialDemandPassed = root.starts() === 0 && root.sameValues([]);
                cavaService.requested = true;
                root.phase = 1;
            } else if (root.phase === 1 && root.starts() === 1 && !root.writeStarted) {
                root.writeStarted = true;
                root.write(["partial:1;;wat", "crlf:;101", "line:4;5"]);
            } else if (root.phase === 1 && root.sameValues([4, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])) {
                root.parsingPassed = true;
                autoCrashTwo.setText("crash\n");
                autoCrashThree.setText("crash\n");
                root.write(["crash"]);
                root.phase = 2;
            } else if (root.phase === 2 && root.starts() === 4) {
                const lines = root.lifecycle().trim().split("\n");
                const startTimes = [];
                for (const line of lines) {
                    const fields = line.split(" ");
                    if (fields[0] === "start")
                        startTimes.push(Number(fields[3]));
                }
                root.retryPassed = startTimes.length === 4 && startTimes[1] - startTimes[0] >= 200 && startTimes[2] - startTimes[1] >= 450 && startTimes[3] - startTimes[2] >= 900;
                root.write(["line:9;8"]);
                root.phase = 3;
            } else if (root.phase === 3 && root.sameValues([9, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])) {
                root.recoveryPassed = true;
                root.write(["crash"]);
                root.phase = 4;
            } else if (root.phase === 4 && root.starts() === 5) {
                cavaService.requested = false;
                root.phase = 5;
            } else if (root.phase === 5 && root.sameValues([]) && root.lifecycle().includes("exit 5 ")) {
                root.stopPassed = true;
                cavaService.requested = true;
                root.phase = 6;
            } else if (root.phase === 6 && root.starts() === 6) {
                root.restartPassed = true;
                delayTermSix.setText("delay\n");
                cavaService.requested = false;
                root.phase = 7;
            } else if (root.phase === 7 && root.lifecycle().includes("term-wait 6 ")) {
                cavaService.requested = true;
                root.phase = 8;
            } else if (root.phase === 8 && root.starts() === 6 && root.sameValues([])) {
                releaseTermSix.setText("release\n");
                root.phase = 9;
            } else if (root.phase === 9 && root.starts() === 7) {
                root.write(["line:7;6"]);
                root.phase = 10;
            } else if (root.phase === 10 && root.sameValues([7, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])) {
                root.rapidDemandPassed = root.lifecycle().includes("exit 6 ");
                delayTermSeven.setText("delay\n");
                cavaService.requested = false;
                root.phase = 11;
            } else if (root.phase === 11 && root.lifecycle().includes("term-wait 7 ")) {
                cavaService.requested = true;
                root.phase = 12;
            } else if (root.phase === 12 && root.starts() === 7 && root.sameValues([])) {
                cavaService.requested = false;
                releaseTermSeven.setText("release\n");
                root.cancelCheckTick = ticks;
                root.phase = 13;
            } else if (root.phase === 13 && root.lifecycle().includes("exit 7 ") && ticks - root.cancelCheckTick >= 20) {
                root.canceledDemandPassed = root.starts() === 7 && root.sameValues([]);
                root.finish(root.initialDemandPassed && root.parsingPassed && root.retryPassed && root.recoveryPassed && root.stopPassed && root.restartPassed && root.rapidDemandPassed && root.canceledDemandPassed, "");
            }
        }
    }

    FileView {
        id: readyFile
        path: root.stateDir + "/ready"
        blockWrites: true
    }

    Component.onCompleted: {
        if (stateDir === "") {
            Qt.exit(2);
            return;
        }
        if (testMode === "destruction")
            cavaService.requested = true;
        if (testMode === "failed-start" || testMode === "failed-start-cancel" || testMode === "failed-start-destruction") {
            root.failedStartAt = Date.now();
            cavaService.requested = true;
        }
    }
}
