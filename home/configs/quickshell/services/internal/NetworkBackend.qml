import QtQuick
import Quickshell
import Quickshell.Networking

QtObject {
    id: root

    property bool scanningRequested: false

    readonly property bool backendPresent: Networking.backend === NetworkBackendType.NetworkManager
    readonly property var wifiDevice: root._selectWifiDevice()
    readonly property bool wifiDevicePresent: root.wifiDevice !== null

    readonly property var wiredSnapshot: {
        const values = (Networking.devices && Networking.devices.values) || [];
        return values.filter(device => device && device.type === DeviceType.Wired).map(device => {
            const network = device.network;
            return {
                id: device.name || "wired",
                name: network && network.name ? network.name : device.name,
                address: device.address || "",
                linkSpeed: device.linkSpeed || 0,
                hasLink: device.hasLink === true && network !== null,
                active: device.connected === true || (network && network.connected === true),
                busy: network ? network.stateChanging === true : false,
                native: network
            };
        });
    }

    // Prefer Networking.connectivity for the bar; fall back to any device
    // connection so wired-only sessions still show as connected.
    readonly property bool connected: {
        const connectivity = Networking.connectivity;
        if (connectivity === NetworkConnectivity.Full || connectivity === NetworkConnectivity.Limited || connectivity === NetworkConnectivity.Portal)
            return true;
        const values = (Networking.devices && Networking.devices.values) || [];
        return values.some(device => device && device.connected === true);
    }

    // Plain-object AP list; native refs stay in NetworkModel's SSID map.
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

    readonly property var vpnDevice: {
        const values = (Networking.devices && Networking.devices.values) || [];
        for (const device of values) {
            if (!device)
                continue;
            const name = (device.name || "").toLowerCase();
            if (name === "wt0" || name.startsWith("netbird") || name.startsWith("tailscale") || name.startsWith("wg") || name.startsWith("gpd") || name.startsWith("tun")) {
                if (device.connected === true || (device.address !== undefined && device.address !== ""))
                    return device;
            }
        }
        return null;
    }

    readonly property bool vpnConnected: root.vpnDevice !== null
    readonly property string vpnName: {
        const dev = root.vpnDevice;
        if (!dev)
            return "";
        const raw = String(dev.name || "");
        const lower = raw.toLowerCase();
        if (lower === "wt0" || lower.startsWith("netbird"))
            return "NetBird (" + raw + ")";
        if (lower.startsWith("tailscale"))
            return "Tailscale (" + raw + ")";
        if (lower.startsWith("gpd"))
            return "GlobalProtect (" + raw + ")";
        return raw;
    }
    readonly property string vpnAddress: root.vpnDevice && root.vpnDevice.address ? String(root.vpnDevice.address) : ""

    // One object-literal so NetworkModel reconciles from a single signal.
    readonly property var observation: {
        return {
            present: root.backendPresent,
            wifiAvailable: root.wifiDevicePresent,
            wifiEnabled: Networking.wifiEnabled,
            connected: root.connected,
            vpnConnected: root.vpnConnected,
            vpnName: root.vpnName,
            vpnAddress: root.vpnAddress,
            wired: root.wiredSnapshot,
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

    function connectWired(nativeNetwork): void {
        if (nativeNetwork)
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
