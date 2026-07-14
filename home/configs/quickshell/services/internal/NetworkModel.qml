import QtQuick
import Quickshell
import Quickshell.Io
import "NetworkParser.js" as NetworkParser
import "NetworkReducer.js" as NetworkReducer

Scope {
    id: root

    property bool scanningRequested: false

    property bool _available: false
    property bool _wifiEnabled: false
    property bool _connected: false
    property string _activeSsid: ""
    property int _activeSignal: 0
    property string _activeSecurity: ""
    property string _busySsid: ""

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

    function _networksArray(): var {
        const out = [];
        for (let i = 0; i < networksModel.count; i++)
            out.push(networksModel.get(i));
        return out;
    }

    function _stateObject(): var {
        return {
            available: root._available,
            wifiEnabled: root._wifiEnabled,
            connected: root._connected,
            activeSsid: root._activeSsid,
            activeSignal: root._activeSignal,
            activeSecurity: root._activeSecurity,
            networks: root._networksArray(),
            busySsid: root._busySsid
        };
    }

    function _applyNetworksModel(list): void {
        networksModel.clear();
        for (const network of list)
            networksModel.append(network);
    }

    function _applyFetch(state): void {
        root._available = state.available;
        root._wifiEnabled = state.wifiEnabled;
        root._activeSsid = state.activeSsid;
        root._activeSignal = state.activeSignal;
        root._activeSecurity = state.activeSecurity;
        root._busySsid = NetworkReducer.reconcileBusy(root._busySsid, state.activeSsid, state.networks);
        root._applyNetworksModel(NetworkReducer.applyBusyRole(state.networks, root._busySsid));
    }

    function _applyGeneral(state): void {
        root._connected = state.connected;
    }

    function setWifiEnabled(enabled: bool): void {
        toggleProcess.command = NetworkParser.radioToggleCommand(enabled);
        toggleProcess.running = true;
    }

    function connectKnown(ssid: string): void {
        if (!ssid || ssid === root._busySsid)
            return;
        root._busySsid = ssid;
        root._applyNetworksModel(NetworkReducer.applyBusyRole(root._networksArray(), root._busySsid));
        connectProcess.command = NetworkParser.connectKnownCommand(ssid);
        connectProcess.running = true;
    }

    function connectInteractive(ssid: string): void {
        if (!ssid)
            return;
        Quickshell.execDetached(NetworkParser.interactiveConnectArgv(ssid));
    }

    function openSettings(): void {
        Quickshell.execDetached(NetworkParser.settingsArgv());
    }

    function _requestFetch(): void {
        fetchProcess.running = true;
    }

    function _requestGeneral(): void {
        generalProcess.running = true;
    }

    Component.onCompleted: {
        root._requestFetch();
        root._requestGeneral();
    }
    onScanningRequestedChanged: {
        fetchTimer.restart();
        root._requestFetch();
    }
    Component.onDestruction: {
        fetchTimer.stop();
        generalTimer.stop();
        fetchProcess.running = false;
        generalProcess.running = false;
        toggleProcess.running = false;
        connectProcess.running = false;
    }

    Process {
        id: fetchProcess
        command: ["sh", "-c", NetworkParser.FETCH_COMMAND]
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root._applyFetch(NetworkReducer.reduceFetch(root._stateObject(), NetworkParser.parseFetchOutput(stdout.text), exitCode));
        }
    }

    Process {
        id: generalProcess
        command: ["sh", "-c", NetworkParser.GENERAL_COMMAND]
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root._applyGeneral(NetworkReducer.reduceGeneral(root._stateObject(), NetworkParser.parseGeneralOutput(stdout.text), exitCode));
        }
    }

    Process {
        id: toggleProcess
        onExited: root._requestFetch()
    }

    Process {
        id: connectProcess
        onExited: root._requestFetch()
    }

    Timer {
        id: fetchTimer
        interval: root.scanningRequested ? 5000 : 20000
        running: true
        repeat: true
        onTriggered: root._requestFetch()
    }

    Timer {
        id: generalTimer
        interval: 3000
        running: true
        repeat: true
        onTriggered: root._requestGeneral()
    }
}
