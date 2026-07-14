import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    id: root

    property string stateDir: Quickshell.env("QS_TEST_STATE_DIR") || ""
    property int phase: 0
    property double phaseStarted: Date.now()
    property bool busyObserved: false
    property int fetchBaselineCount: 0
    property bool interactiveSent: false
    property bool settingsSent: false

    Services.NetworkService {
        id: networkService
    }

    function elapsed(): double {
        return Date.now() - root.phaseStarted;
    }
    function advance(): void {
        root.phase++;
        root.phaseStarted = Date.now();
    }
    function fileLines(view): var {
        view.reload();
        view.waitForJob();
        return view.text().split("\n").map(line => line.trim()).filter(line => line !== "");
    }
    function radioQueryCount(): int {
        return root.fileLines(callsFile).filter(line => line === "radio wifi").length;
    }
    function networkByName(ssid): var {
        for (let i = 0; i < networkService.networks.count; i++) {
            const row = networkService.networks.get(i);
            if (row.ssid === ssid)
                return row;
        }
        return null;
    }
    function fail(message): void {
        resultFile.setText(JSON.stringify({
            passed: false,
            phase: root.phase,
            error: message
        }) + "\n");
        Qt.quit();
    }
    function finish(): void {
        resultFile.setText(JSON.stringify({
            passed: true,
            busyObserved: root.busyObserved,
            diagnostics: {
                available: networkService.available,
                wifiEnabled: networkService.wifiEnabled,
                connected: networkService.connected,
                activeSsid: networkService.activeSsid,
                activeSignal: networkService.activeSignal,
                activeSecurity: networkService.activeSecurity,
                networkCount: networkService.networks.count
            }
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
        id: callsFile
        path: root.stateDir + "/network/calls.log"
        blockLoading: true
    }
    FileView {
        id: connectFile
        path: root.stateDir + "/network/connect-calls.log"
        blockLoading: true
    }
    FileView {
        id: toggleFile
        path: root.stateDir + "/network/toggle-calls.log"
        blockLoading: true
    }
    FileView {
        id: kittyFile
        path: root.stateDir + "/kitty-calls.log"
        blockLoading: true
    }

    Component.onCompleted: readyFile.setText("ready\n")

    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (root.elapsed() > 30000)
                return root.fail("phase timeout");

            if (root.phase === 0) {
                if (!networkService.available || networkService.networks.count !== 2)
                    return;
                if (networkService.activeSsid !== "Home" || networkService.activeSignal !== 80 || networkService.activeSecurity !== "WPA2")
                    return root.fail("initial active-network fields did not match fixture snapshot");
                if (!networkService.wifiEnabled || !networkService.connected)
                    return root.fail("initial wifiEnabled/connected did not match fixture snapshot");
                const home = root.networkByName("Home");
                const guest = root.networkByName("Guest");
                if (!home || !guest)
                    return root.fail("expected both Home and Guest in the discovery list");
                if (networkService.networks.get(0).ssid !== "Home")
                    return root.fail("networks were not sorted by descending signal");
                if (!home.known || !home.active || home.busy)
                    return root.fail("Home role flags did not match known/active/busy expectations");
                if (guest.known || guest.active || guest.busy || guest.secure)
                    return root.fail("Guest role flags did not match unknown/open expectations");
                root.advance();
            } else if (root.phase === 1) {
                networkService.setWifiEnabled(false);
                root.advance();
            } else if (root.phase === 2) {
                if (networkService.wifiEnabled)
                    return;
                if (root.fileLines(toggleFile).join(",") !== "off")
                    return root.fail("setWifiEnabled(false) did not issue exactly one radio-off command");
                networkService.setWifiEnabled(true);
                root.advance();
            } else if (root.phase === 3) {
                if (!networkService.wifiEnabled)
                    return;
                if (root.fileLines(toggleFile).join(",") !== "off,on")
                    return root.fail("setWifiEnabled(true) did not issue exactly one radio-on command after the prior toggle");
                networkService.connectKnown("Home");
                const home = root.networkByName("Home");
                if (home && home.busy)
                    root.busyObserved = true;
                root.advance();
            } else if (root.phase === 4) {
                const connectCalls = root.fileLines(connectFile);
                if (connectCalls.length === 0)
                    return;
                if (connectCalls.join(",") !== "Home")
                    return root.fail("connectKnown did not issue exactly the expected nmcli connect argv");
                const home = root.networkByName("Home");
                if (home && home.busy)
                    return; // wait for the follow-up fetch to clear busy now that Home is confirmed active
                root.advance();
            } else if (root.phase === 5) {
                if (!root.interactiveSent) {
                    root.interactiveSent = true;
                    networkService.connectInteractive("Guest");
                }
                if (!root.fileLines(kittyFile).some(line => line === "-e nmtui-connect Guest"))
                    return;
                root.advance();
            } else if (root.phase === 6) {
                if (!root.settingsSent) {
                    root.settingsSent = true;
                    networkService.openSettings();
                }
                if (!root.fileLines(kittyFile).some(line => line === "-e sudo nmtui"))
                    return;
                root.advance();
            } else if (root.phase === 7) {
                root.fetchBaselineCount = root.radioQueryCount();
                networkService.scanningRequested = true;
                root.advance();
            } else if (root.phase === 8) {
                if (root.radioQueryCount() <= root.fetchBaselineCount)
                    return;
                if (!root.busyObserved)
                    return root.fail("busy was never observable during connectKnown");
                root.finish();
            }
        }
    }
}
