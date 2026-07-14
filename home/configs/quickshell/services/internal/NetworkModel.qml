import QtQuick
import Quickshell
import "NetworkParser.js" as NetworkParser
import "NetworkReducer.js" as NetworkReducer

Scope {
    id: root

    required property var backend
    property bool scanningRequested: false

    property bool _available: false
    property bool _wifiEnabled: false
    property bool _connected: false
    property string _activeSsid: ""
    property int _activeSignal: 0
    property string _activeSecurity: ""
    property string _busySsid: ""
    // Frozen native-shaped discovery entries (ssid/signal/security/secure/known);
    // only replaced while scanningRequested, so the popup's AP list survives
    // scanner-off gaps instead of shrinking as native entries expire.
    property var _discovery: []
    property var _nativeBySsid: ({})

    readonly property bool available: _available
    readonly property bool wifiEnabled: _wifiEnabled
    readonly property bool connected: _connected
    readonly property string activeSsid: _activeSsid
    readonly property int activeSignal: _activeSignal
    readonly property string activeSecurity: _activeSecurity
    property alias networks: networksModel

    ListModel {
        id: networksModel
    }

    function _applyNetworksModel(list): void {
        networksModel.clear();
        for (const network of list)
            networksModel.append(network);
    }

    function _renderDiscovery(): void {
        const list = NetworkReducer.buildNetworkListFromNativeSnapshot(root._discovery, root._activeSsid);
        root._applyNetworksModel(NetworkReducer.applyBusyRole(list, root._busySsid));
    }

    function _reconcile(): void {
        const observation = root.backend ? root.backend.observation : null;
        root._available = !!(observation && observation.present);
        if (!root._available)
            return; // retain previously observed wifiEnabled/active/discovery fields

        root._wifiEnabled = observation.wifiEnabled;
        root._connected = observation.connected;

        const liveEntries = observation.networks || [];
        root._nativeBySsid = {};
        for (const entry of liveEntries)
            root._nativeBySsid[entry.ssid] = entry.native;

        const activeEntry = liveEntries.find(entry => entry.active);
        root._activeSsid = activeEntry ? activeEntry.ssid : "";
        root._activeSignal = activeEntry ? activeEntry.signal : 0;
        root._activeSecurity = activeEntry ? activeEntry.security : "";

        root._busySsid = NetworkReducer.reconcileBusy(root._busySsid, root._activeSsid, liveEntries);

        if (root.scanningRequested || root._discovery.length === 0) {
            root._discovery = liveEntries.map(entry => ({
                    ssid: entry.ssid,
                    signal: entry.signal,
                    security: entry.security,
                    secure: entry.secure,
                    known: entry.known
                }));
        }
        root._renderDiscovery();
    }

    function setWifiEnabled(enabled: bool): void {
        if (root.backend)
            root.backend.setWifiEnabled(enabled);
    }

    function connectKnown(ssid: string): void {
        if (!ssid || ssid === root._busySsid || !root.backend)
            return;
        const native = root._nativeBySsid[ssid];
        if (!native)
            return;
        root._busySsid = ssid;
        root._renderDiscovery();
        root.backend.connectNetwork(native);
    }

    function connectInteractive(ssid: string): void {
        if (!ssid)
            return;
        Quickshell.execDetached(NetworkParser.interactiveConnectArgv(ssid));
    }

    function openSettings(): void {
        Quickshell.execDetached(NetworkParser.settingsArgv());
    }

    onScanningRequestedChanged: {
        if (root.backend)
            root.backend.scanningRequested = root.scanningRequested;
    }
    onBackendChanged: {
        if (root.backend)
            root.backend.scanningRequested = root.scanningRequested;
        root._reconcile();
    }
    Component.onCompleted: root._reconcile()

    property Connections _backendConnections: Connections {
        target: root.backend

        function onObservationChanged(): void {
            root._reconcile();
        }

        function onConnectionFailed(ssid, noSecrets): void {
            if (ssid && ssid === root._busySsid) {
                root._busySsid = "";
                root._renderDiscovery();
            }
            if (noSecrets && ssid)
                root.connectInteractive(ssid);
        }
    }
}
