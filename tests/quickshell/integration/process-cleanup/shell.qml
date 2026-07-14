import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""
    property string testMode: Quickshell.env("QS_TEST_MODE") || "normal"
    property string lifecycleStage: "initial"
    property int startCount: 0
    property int overlapSuppressed: 0
    property int retryRequests: 0
    property int retryAttempts: 0
    property int retryCoalesced: 0
    property int destructionChecks: 0
    property string initialProcessId: ""
    property string currentProcessId: ""
    property string generationReadyAction: ""
    property string pendingTeardownAction: ""
    property bool destructionObserved: false
    property bool noRestartObserved: false
    property bool pendingHardReload: false

    function requestStart() {
        if (ownerLoader.item && ownerLoader.item.managedProcess.running) {
            overlapSuppressed++;
            return;
        }
        ownerLoader.active = true;
    }

    function requestRetry() {
        retryRequests++;
        if (retryTimer.running) {
            retryCoalesced++;
            return;
        }
        retryTimer.start();
    }

    function handleStarted() {
        startCount++;

        if (testMode === "term") {
            readyFile.setText("ready\n");
            return;
        }

        currentProcessId = ownerLoader.item.managedProcess.processId.toString();
        if (lifecycleStage === "initial") {
            initialProcessId = currentProcessId;
            generationReadyAction = "initial-policy";
        } else if (lifecycleStage === "reload-soft") {
            generationReadyAction = "soft-reload";
        } else if (lifecycleStage === "soft") {
            generationReadyAction = "hard-reload";
        } else if (lifecycleStage === "hard") {
            generationReadyAction = "final-stop";
        }
        processReadyTimer.start();
    }

    function handleGenerationReady() {
        if (generationReadyAction === "initial-policy") {
            beginInitialPolicyChecks();
        } else if (generationReadyAction === "soft-reload") {
            diagnosticsFile.setText(JSON.stringify({
                overlapSuppressed: overlapSuppressed,
                retryRequests: retryRequests,
                retryAttempts: retryAttempts,
                retryCoalesced: retryCoalesced,
                intentionalStarts: startCount,
                noRestartAfterDestruction: noRestartObserved
            }));
            requestTeardown("soft-reload");
        } else if (generationReadyAction === "hard-reload") {
            requestTeardown("hard-reload");
        } else if (generationReadyAction === "final-stop") {
            requestTeardown("final-stop");
        }
    }

    function requestTeardown(action) {
        pendingTeardownAction = action;
        teardownPublishTimer.start();
    }

    function performApprovedTeardown() {
        teardownApprovalTimer.stop();
        if (pendingTeardownAction === "loader-destroy") {
            ownerLoader.active = false;
            destructionCheckTimer.start();
        } else if (pendingTeardownAction === "soft-reload") {
            phaseFile.setText("soft\n");
            pendingHardReload = false;
            reloadTimer.start();
        } else if (pendingTeardownAction === "hard-reload") {
            phaseFile.setText("hard\n");
            pendingHardReload = true;
            reloadTimer.start();
        } else if (pendingTeardownAction === "final-stop") {
            finalStopTimer.start();
        }
    }

    function beginInitialPolicyChecks() {
        readyFile.setText("ready\n");
        requestStart();
        requestStart();
        requestRetry();
        requestRetry();
        requestRetry();
    }

    function observeLoaderDestruction() {
        lifecycleFile.reload();
        const lifecycle = lifecycleFile.text();
        const directExitObserved = lifecycle.includes(" child-owner-gone ") && lifecycle.includes(" " + initialProcessId + " ");

        if (!destructionObserved) {
            if (!directExitObserved)
                return;
            destructionObserved = true;
            destructionChecks = 0;
            return;
        }

        destructionChecks++;
        if (destructionChecks < 5)
            return;

        destructionCheckTimer.stop();
        noRestartObserved = startCount === 1 && !ownerLoader.active;
        if (!noRestartObserved) {
            resultFile.setText(JSON.stringify({
                passed: false,
                diagnostics: {
                    error: "process restarted after Loader destruction"
                }
            }) + "\n");
            Qt.quit();
            return;
        }

        lifecycleStage = "reload-soft";
        ownerLoader.active = true;
    }

    function handleExited() {
        if (testMode !== "normal")
            return;

        if (lifecycleStage === "hard") {
            const policy = JSON.parse(diagnosticsFile.text());
            const passed = policy.overlapSuppressed === 2 && policy.retryRequests === 4 && policy.retryAttempts === 2 && policy.retryCoalesced === 2 && policy.intentionalStarts === 2 && policy.noRestartAfterDestruction;
            resultFile.setText(JSON.stringify({
                passed: passed,
                diagnostics: {
                    policy: policy,
                    finalGenerationStarts: startCount,
                    completedSoftReload: true,
                    completedHardReload: true,
                    noRestartAfterDestruction: policy.noRestartAfterDestruction
                }
            }) + "\n");
            Qt.quit();
        }
    }

    Component {
        id: processOwnerComponent

        Item {
            visible: false
            property alias managedProcess: ownedProcess

            Process {
                id: ownedProcess
                running: true
                command: [root.stateDir + "/fixture-bin/qs-test-owned-process", root.lifecycleStage]
                environment: ({
                        QS_TEST_OWNER_PID: Quickshell.processId.toString()
                    })
                onStarted: root.handleStarted()
                onExited: root.handleExited()
            }
        }
    }

    Loader {
        id: ownerLoader
        active: true
        sourceComponent: processOwnerComponent
    }

    FileView {
        id: phaseFile
        path: root.stateDir + "/phase"
        blockLoading: true
        blockWrites: true
    }

    FileView {
        id: diagnosticsFile
        path: root.stateDir + "/diagnostics.json"
        blockLoading: true
        blockWrites: true
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
        id: processReadyFile
        path: root.stateDir + "/ready." + root.currentProcessId
        blockAllReads: true
        printErrors: false
    }

    FileView {
        id: lifecycleFile
        path: root.stateDir + "/lifecycle.log"
        blockAllReads: true
        printErrors: false
    }

    FileView {
        id: teardownRequestFile
        path: root.stateDir + "/teardown-request." + root.pendingTeardownAction
        blockWrites: true
        printErrors: false
    }

    FileView {
        id: teardownApprovalFile
        path: root.stateDir + "/teardown-approved." + root.pendingTeardownAction
        blockAllReads: true
        printErrors: false
    }

    Timer {
        id: processReadyTimer
        interval: 20
        repeat: true
        onTriggered: {
            processReadyFile.reload();
            if (processReadyFile.text().trim() !== "ready")
                return;
            stop();
            root.handleGenerationReady();
        }
    }

    Timer {
        id: teardownPublishTimer
        interval: 20
        repeat: false
        onTriggered: {
            teardownRequestFile.setText("request\n");
            teardownApprovalTimer.start();
        }
    }

    Timer {
        id: teardownApprovalTimer
        interval: 20
        repeat: true
        onTriggered: {
            teardownApprovalFile.reload();
            if (teardownApprovalFile.text().trim() !== "approved")
                return;
            root.performApprovedTeardown();
        }
    }

    Timer {
        id: retryTimer
        interval: 20
        repeat: false
        onTriggered: {
            root.retryAttempts++;
            if (root.retryAttempts < 2) {
                root.requestRetry();
            } else {
                root.requestTeardown("loader-destroy");
            }
        }
    }

    Timer {
        id: destructionCheckTimer
        interval: 20
        repeat: true
        onTriggered: root.observeLoaderDestruction()
    }

    Timer {
        id: reloadTimer
        interval: 20
        repeat: false
        onTriggered: Quickshell.reload(root.pendingHardReload)
    }

    Timer {
        id: finalStopTimer
        interval: 100
        repeat: false
        onTriggered: ownerLoader.item.managedProcess.running = false
    }

    Component.onCompleted: {
        if (stateDir === "") {
            console.error("QS_TEST_STATE_DIR is required");
            Qt.exit(2);
            return;
        }

        if (testMode === "normal") {
            const savedPhase = phaseFile.text().trim();
            lifecycleStage = savedPhase === "" ? "initial" : savedPhase;
        }
    }
}
