import QtQuick
import QtTest
import "../../../home/configs/quickshell/services/internal/NetworkParser.js" as NetworkParser
import "../../../home/configs/quickshell/services/internal/NetworkReducer.js" as NetworkReducer

TestCase {
    name: "NetworkReducer"

    function fetchText(radio, savedLines, netLines) {
        var lines = [];
        if (radio !== null && radio !== undefined)
            lines.push("radio|" + radio);
        else
            lines.push("radio|");
        for (var i = 0; i < (savedLines || []).length; i++)
            lines.push("saved|" + savedLines[i]);
        for (var j = 0; j < (netLines || []).length; j++)
            lines.push("net|" + netLines[j]);
        return lines.join("\n") + "\n";
    }

    // --- NetworkParser: current nmcli framing -----------------------------

    function test_parseFetchOutputCurrentFraming() {
        var text = fetchText("enabled", ["Home"], ["*|Home|80|WPA2", "|Guest|40|--"]);
        var parsed = NetworkParser.parseFetchOutput(text);
        verify(parsed.radioPresent);
        verify(parsed.radioEnabled);
        compare(parsed.activeSsid, "Home");
        compare(parsed.activeSignal, 80);
        compare(parsed.activeSecurity, "WPA2");
        compare(parsed.rawNetworks.length, 2);
        compare(parsed.saved.Home, true);
    }

    function test_parseFetchOutputNoDevice() {
        var parsed = NetworkParser.parseFetchOutput(fetchText(null, [], []));
        verify(!parsed.radioPresent);
        verify(!parsed.radioEnabled);
        compare(parsed.rawNetworks.length, 0);
    }

    function test_parseFetchOutputEnabledDisabledRadio() {
        verify(NetworkParser.parseFetchOutput(fetchText("enabled", [], [])).radioEnabled);
        verify(!NetworkParser.parseFetchOutput(fetchText("disabled", [], [])).radioEnabled);
    }

    function test_parseFetchOutputOpenAndSecuredSecurity() {
        var parsed = NetworkParser.parseFetchOutput(fetchText("enabled", [], ["|OpenNet|50|--", "|SecureNet|60|WPA2"]));
        var open = parsed.rawNetworks.find(n => n.ssid === "OpenNet");
        var secure = parsed.rawNetworks.find(n => n.ssid === "SecureNet");
        verify(!open.secure);
        compare(open.security, "open");
        verify(secure.secure);
        compare(secure.security, "WPA2");
    }

    function test_parseGeneralOutputConnectedAndAbsent() {
        verify(NetworkParser.parseGeneralOutput("connected\n").connected);
        verify(!NetworkParser.parseGeneralOutput("connecting\n").connected);
        verify(!NetworkParser.parseGeneralOutput("").present);
    }

    // --- NetworkReducer: dedup/sort/cap/roles ------------------------------

    function test_buildNetworkListDedupsByStrongestSignal() {
        var raw = [
            {
                ssid: "Dup",
                signal: 30,
                security: "open",
                secure: false
            },
            {
                ssid: "Dup",
                signal: 70,
                security: "open",
                secure: false
            }
        ];
        var list = NetworkReducer.buildNetworkList(raw, {}, "");
        compare(list.length, 1);
        compare(list[0].signal, 70);
    }

    function test_buildNetworkListSortsDescending() {
        var raw = [
            {
                ssid: "A",
                signal: 10,
                security: "open",
                secure: false
            },
            {
                ssid: "B",
                signal: 90,
                security: "open",
                secure: false
            },
            {
                ssid: "C",
                signal: 50,
                security: "open",
                secure: false
            }
        ];
        var list = NetworkReducer.buildNetworkList(raw, {}, "");
        compare(list.map(n => n.ssid), ["B", "C", "A"]);
    }

    function test_buildNetworkListCapsAtEightEntries() {
        var raw = [];
        for (var i = 0; i < 12; i++)
            raw.push({
                ssid: "Net" + i,
                signal: 100 - i,
                security: "open",
                secure: false
            });
        var list = NetworkReducer.buildNetworkList(raw, {}, "");
        compare(list.length, 8);
        compare(list[0].ssid, "Net0");
        compare(list[7].ssid, "Net7");
    }

    function test_buildNetworkListKnownRoleFromSavedOrActive() {
        var raw = [
            {
                ssid: "Saved",
                signal: 50,
                security: "WPA2",
                secure: true
            },
            {
                ssid: "ActiveOnly",
                signal: 60,
                security: "WPA2",
                secure: true
            },
            {
                ssid: "Neither",
                signal: 40,
                security: "WPA2",
                secure: true
            }
        ];
        var list = NetworkReducer.buildNetworkList(raw, {
            Saved: true
        }, "ActiveOnly");
        var byName = {};
        list.forEach(n => byName[n.ssid] = n);
        verify(byName.Saved.known);
        verify(byName.ActiveOnly.known);
        verify(byName.ActiveOnly.active);
        verify(!byName.Neither.known);
        verify(!byName.Neither.active);
    }

    function test_buildNetworkListMultipleDevicesMergedByAwk() {
        // Multiple wifi devices are merged upstream by the same nmcli
        // invocation (no per-device framing); the reducer only ever sees a
        // flat rawNetworks array, so duplicate SSIDs across devices dedup
        // exactly like duplicate scan results from one device.
        var raw = [
            {
                ssid: "Shared",
                signal: 55,
                security: "open",
                secure: false
            },
            {
                ssid: "Shared",
                signal: 65,
                security: "open",
                secure: false
            },
            {
                ssid: "Device2Only",
                signal: 20,
                security: "open",
                secure: false
            }
        ];
        var list = NetworkReducer.buildNetworkList(raw, {}, "");
        compare(list.length, 2);
        compare(list[0].ssid, "Shared");
        compare(list[0].signal, 65);
    }

    // --- NetworkReducer: fetch/general reduction with malformed handling --

    function test_reduceFetchMalformedOrFailedPreservesPrevious() {
        var previous = NetworkReducer.reduceFetch(NetworkReducer.initialState(), NetworkParser.parseFetchOutput(fetchText("enabled", ["Home"], ["*|Home|80|WPA2"])), 0);
        verify(previous.available);

        var daemonAbsent = NetworkReducer.reduceFetch(previous, NetworkParser.parseFetchOutput(fetchText(null, [], [])), 0);
        verify(!daemonAbsent.available);
        compare(daemonAbsent.activeSsid, "Home");
        compare(daemonAbsent.networks.length, 1);

        var failedExit = NetworkReducer.reduceFetch(previous, NetworkParser.parseFetchOutput(fetchText("enabled", ["Home"], ["*|Home|80|WPA2"])), 1);
        verify(!failedExit.available);
        compare(failedExit.activeSsid, "Home");
    }

    function test_reduceFetchDaemonAbsentRequiresReloadNotFabricatedRecovery() {
        // "Recovery" here is just the next successful poll on the normal
        // cadence — reduceFetch itself must never synthesize an available
        // state from a daemon-absent snapshot, no matter how many times it
        // is folded.
        var state = NetworkReducer.initialState();
        for (var i = 0; i < 5; i++)
            state = NetworkReducer.reduceFetch(state, NetworkParser.parseFetchOutput(fetchText(null, [], [])), 0);
        verify(!state.available);
        compare(state.networks.length, 0);
    }

    function test_reduceGeneralPreservesPreviousOnFailure() {
        var connectedState = NetworkReducer.reduceGeneral(NetworkReducer.initialState(), NetworkParser.parseGeneralOutput("connected\n"), 0);
        verify(connectedState.connected);
        var afterFailure = NetworkReducer.reduceGeneral(connectedState, NetworkParser.parseGeneralOutput(""), 1);
        verify(afterFailure.connected);
    }

    // --- NetworkReducer: busy clearing -------------------------------------

    function test_reconcileBusyClearsOnActiveMatch() {
        compare(NetworkReducer.reconcileBusy("Home", "Home", [
            {
                ssid: "Home"
            }
        ]), "");
    }

    function test_reconcileBusyClearsOnDisappearance() {
        compare(NetworkReducer.reconcileBusy("Gone", "", []), "");
    }

    function test_reconcileBusyRetainedWhilePresentAndNotActive() {
        compare(NetworkReducer.reconcileBusy("Pending", "", [
            {
                ssid: "Pending"
            }
        ]), "Pending");
    }

    function test_applyBusyRoleSetsOnlyMatchingNetwork() {
        var list = NetworkReducer.buildNetworkList([
            {
                ssid: "A",
                signal: 50,
                security: "open",
                secure: false
            },
            {
                ssid: "B",
                signal: 40,
                security: "open",
                secure: false
            }
        ], {}, "");
        var withBusy = NetworkReducer.applyBusyRole(list, "B");
        var byName = {};
        withBusy.forEach(n => byName[n.ssid] = n);
        verify(!byName.A.busy);
        verify(byName.B.busy);
    }

    // --- NetworkParser: action/settings argv (no-secrets fallback) --------

    function test_interactiveConnectArgvForUnknownOrNoSecrets() {
        compare(NetworkParser.interactiveConnectArgv("OpenCafe"), ["kitty", "-e", "nmtui-connect", "OpenCafe"]);
    }

    function test_connectKnownCommandArgv() {
        compare(NetworkParser.connectKnownCommand("Home"), ["nmcli", "dev", "wifi", "connect", "Home"]);
    }

    function test_radioToggleCommandArgv() {
        compare(NetworkParser.radioToggleCommand(true), ["nmcli", "radio", "wifi", "on"]);
        compare(NetworkParser.radioToggleCommand(false), ["nmcli", "radio", "wifi", "off"]);
    }

    function test_settingsArgv() {
        compare(NetworkParser.settingsArgv(), ["kitty", "-e", "sudo", "nmtui"]);
    }
}
