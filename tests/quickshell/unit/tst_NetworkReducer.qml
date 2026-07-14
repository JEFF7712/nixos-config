import QtQuick
import QtTest
import "../../../home/configs/quickshell/services/internal/NetworkParser.js" as NetworkParser
import "../../../home/configs/quickshell/services/internal/NetworkReducer.js" as NetworkReducer

TestCase {
    name: "NetworkReducer"

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

    function test_buildNetworkListFromNativeSnapshotUsesNativeKnownFlags() {
        var snapshot = [
            {
                ssid: "KnownWeak",
                signal: 20,
                security: "WPA2",
                secure: true,
                known: true
            },
            {
                ssid: "KnownWeak",
                signal: 80,
                security: "WPA2",
                secure: true,
                known: true
            },
            {
                ssid: "Unknown",
                signal: 50,
                security: "open",
                secure: false,
                known: false
            },
            {
                ssid: "Active",
                signal: 60,
                security: "WPA2",
                secure: true,
                known: false
            }
        ];
        var list = NetworkReducer.buildNetworkListFromNativeSnapshot(snapshot, "Active");
        compare(list.length, 3);
        compare(list[0].ssid, "KnownWeak");
        compare(list[0].signal, 80);
        verify(list[0].known);
        verify(list[1].known); // Active counts as known via activeSsid
        verify(list[1].active);
        verify(!list[2].known);
    }

    function test_buildNetworkListFromNativeSnapshotCapsAndSorts() {
        var snapshot = [];
        for (var i = 0; i < 12; i++)
            snapshot.push({
                ssid: "Net" + i,
                signal: i * 5,
                security: "open",
                secure: false,
                known: false
            });
        var list = NetworkReducer.buildNetworkListFromNativeSnapshot(snapshot, "");
        compare(list.length, 8);
        compare(list[0].ssid, "Net11");
        compare(list[7].ssid, "Net4");
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

    // --- NetworkParser: interactive escape hatches -------------------------

    function test_interactiveConnectArgvForUnknownOrNoSecrets() {
        compare(NetworkParser.interactiveConnectArgv("OpenCafe"), ["kitty", "-e", "nmtui-connect", "OpenCafe"]);
    }

    function test_settingsArgv() {
        compare(NetworkParser.settingsArgv(), ["kitty", "-e", "sudo", "nmtui"]);
    }
}
