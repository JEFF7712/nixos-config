import QtQuick
import Quickshell
import Quickshell.Bluetooth

QtObject {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool adapterPresent: root.adapter !== null && root.adapter !== undefined

    // Plain-object snapshot of paired devices; keeps a native object
    // reference per entry for BluetoothModel's id-to-object action map.
    readonly property var deviceSnapshot: {
        const adapter = root.adapter;
        const values = (adapter && adapter.devices && adapter.devices.values) || [];
        const snapshot = [];
        for (const device of values) {
            if (!device || device.paired !== true)
                continue;
            const address = device.address || "";
            if (!address)
                continue;
            const state = device.state;
            const busy = state === BluetoothDeviceState.Connecting || state === BluetoothDeviceState.Disconnecting;
            snapshot.push({
                id: address,
                name: device.name || device.deviceName || address,
                connected: device.connected === true,
                busy: busy,
                native: device
            });
        }
        return snapshot;
    }

    // A single object-literal binding so BluetoothModel can reconcile from
    // one signal (onObservationChanged), matching the Network/UPower pattern.
    readonly property var observation: {
        return {
            present: root.adapterPresent,
            enabled: root.adapterPresent ? root.adapter.enabled === true : false,
            adapter: root.adapterPresent ? (root.adapter.adapterId || root.adapter.name || "") : "",
            devices: root.deviceSnapshot
        };
    }

    function setEnabled(enabled: bool): void {
        if (!root.adapter)
            return;
        root.adapter.enabled = enabled;
    }

    function toggleDevice(nativeDevice): void {
        if (!nativeDevice)
            return;
        if (nativeDevice.connected)
            nativeDevice.disconnect();
        else
            nativeDevice.connect();
    }
}
