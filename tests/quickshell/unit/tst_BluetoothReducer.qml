import QtQuick
import QtTest
import "../../../home/configs/quickshell/services/internal/BluetoothParser.js" as BluetoothParser
import "../../../home/configs/quickshell/services/internal/BluetoothReducer.js" as BluetoothReducer

TestCase {
    name: "BluetoothReducer"

    function fetchText(adapter, powered, devices) {
        var lines = ["adapter|" + (adapter || "")];
        if (adapter)
            lines.push("powered|" + (powered ? "true" : "false"));
        for (var i = 0; i < (devices || []).length; i++) {
            var d = devices[i];
            lines.push("dev|" + d.id + "|" + (d.connected ? "true" : "false") + "|" + d.name);
        }
        return lines.join("\n") + "\n";
    }

    function test_parseNoAdapter() {
        var parsed = BluetoothParser.parseFetchOutput(fetchText("", false, []));
        verify(!parsed.adapterPresent);
    }

    function test_parsePoweredAndPairedDevices() {
        var parsed = BluetoothParser.parseFetchOutput(fetchText("/org/bluez/hci0", true, [
            {
                id: "/org/bluez/hci0/dev_AA",
                connected: true,
                name: "Buds"
            },
            {
                id: "/org/bluez/hci0/dev_BB",
                connected: false,
                name: "Keyboard"
            }
        ]));
        verify(parsed.adapterPresent);
        verify(parsed.enabled);
        compare(parsed.devices.length, 2);
    }

    function test_sortConnectedFirstThenName() {
        var list = BluetoothReducer.sortDevices([
            {
                id: "b",
                name: "Zebra",
                connected: false
            },
            {
                id: "a",
                name: "Alpha",
                connected: false
            },
            {
                id: "c",
                name: "Mouse",
                connected: true
            }
        ]);
        compare(list.map(d => d.name), ["Mouse", "Alpha", "Zebra"]);
    }

    function test_reduceFetchPreservesOnFailureAndClearsBusyOnDisappearance() {
        var previous = BluetoothReducer.reduceFetch(null, BluetoothParser.parseFetchOutput(fetchText("/org/bluez/hci0", true, [
            {
                id: "/org/bluez/hci0/dev_AA",
                connected: false,
                name: "Buds"
            }
        ])), 0);
        previous.busyId = "/org/bluez/hci0/dev_AA";
        var failed = BluetoothReducer.reduceFetch(previous, BluetoothParser.parseFetchOutput(fetchText("/org/bluez/hci0", true, [
            {
                id: "/org/bluez/hci0/dev_AA",
                connected: false,
                name: "Buds"
            }
        ])), 1);
        verify(!failed.available);
        compare(failed.devices.length, 1);

        var gone = BluetoothReducer.reduceFetch(previous, BluetoothParser.parseFetchOutput(fetchText("/org/bluez/hci0", true, [])), 0);
        compare(gone.busyId, "");
    }

    function test_commandArgv() {
        compare(BluetoothParser.setEnabledCommand("/org/bluez/hci0", true), ["busctl", "--system", "set-property", "org.bluez", "/org/bluez/hci0", "org.bluez.Adapter1", "Powered", "b", "true"]);
        compare(BluetoothParser.toggleDeviceCommand("/org/bluez/hci0/dev_AA", true), ["busctl", "--system", "call", "org.bluez", "/org/bluez/hci0/dev_AA", "org.bluez.Device1", "Connect"]);
        compare(BluetoothParser.openManagerCommand(), ["blueman-manager"]);
    }
}
