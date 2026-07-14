import QtQuick
import Quickshell
import Quickshell.Networking

QtObject {
    id: root

    property bool scanningRequested: false

    readonly property bool backendPresent: Networking.backend === NetworkBackendType.NetworkManager
    readonly property var wifiDevice: root._selectWifiDevice()
    readonly property bool wifiDevicePresent: root.wifiDevice !== null

    // Prefer Networking.connectivity for the bar; fall back to any device
    // connection so wired-only sessions still show as connected.
    readonly property bool connected: {
        const connectivity = Networking.connectivity;
        if (connectivity === NetworkConnectivity.Full
            || connectivity === NetworkConnectivity.Limited
            || connectivity === NetworkConnectivity.Portal)
            return true;
        const values = (Networking.devices && Networking.devices.values) || [];
        return values.some(device => device && device.connected === true);
    }

    // Plain-object snapshot of the selected Wi-Fi device's current AP list;
    // keeps a native object reference per entry for NetworkModel's
    // SSID-to-native-object action map without exposing native types itself.
    readonly property var networkSnapshot: {
        const device = root.wifiDevice;
        const values = (device && device.networks && device.networks.values) || [];
        const snapshot = [];
        for (const network of values) {
            const ssid = network && network.name ? network.name : "";
            if (!ssid)
                continue;
            const open = network.security === WifiSecurityType.Open;
            snapshot.push({
                ssid: ssid,
                signal: Math.max(0, Math.min(100, Math.round(network.signalStrength || 0))),
                secure: !open,
                security: open ? "open" : WifiSecurityType.toString(network.security),
                known: network.known === true,
                active: network.connected === true,
                native: network
            });
        }
        return snapshot;
    }

    // A single object-literal binding so NetworkModel can reconcile from one
    // signal (onObservationChanged) instead of wiring a Connections handler
    // per native property, matching the UPower/Pipewire backend pattern.
    readonly property var observation: {
        return {
            present: root.backendPresent && root.wifiDevicePresent,
            wifiEnabled: Networking.wifiEnabled,
            connected: root.connected,
            networks: root.networkSnapshot
        };
    }

    property var _pendingNetwork: null

    signal connectionFailed(string ssid, bool noSecrets)

    function _selectWifiDevice(): var {
        const values = (Networking.devices && Networking.devices.values) || [];
        const wifiDevices = values.filter(device => device && device.type === DeviceType.Wifi);
        wifiDevices.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        return wifiDevices.length > 0 ? wifiDevices[0] : null;
    }

    function _applyScanning(): void {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = root.scanningRequested;
    }

    function setWifiEnabled(enabled: bool): void {
        Networking.wifiEnabled = enabled;
    }

    function connectNetwork(nativeNetwork): void {
        if (!nativeNetwork)
            return;
        root._pendingNetwork = nativeNetwork;
        nativeNetwork.connect();
    }

    onScanningRequestedChanged: root._applyScanning()
    onWifiDeviceChanged: root._applyScanning()
    Component.onCompleted: root._applyScanning()

    property Connections _pendingConnections: Connections {
        target: root._pendingNetwork

        function onConnectionFailed(reason): void {
            const ssid = root._pendingNetwork ? root._pendingNetwork.name : "";
            root._pendingNetwork = null;
            root.connectionFailed(ssid, reason === ConnectionFailReason.NoSecrets);
        }
    }
}
