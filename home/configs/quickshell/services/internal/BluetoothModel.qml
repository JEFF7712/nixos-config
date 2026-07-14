import QtQuick
import Quickshell
import Quickshell.Io
import "BluetoothParser.js" as BluetoothParser
import "BluetoothReducer.js" as BluetoothReducer

Scope {
    id: root

    property bool detailedMonitoring: false

    property bool _available: false
    property bool _enabled: false
    property string _adapter: ""
    property string _busyId: ""

    readonly property bool available: _available
    readonly property bool enabled: _enabled
    readonly property int connectedCount: BluetoothReducer.connectedCount(_deviceList())
    property alias devices: devicesModel

    ListModel {
        id: devicesModel
    }

    function _deviceList(): var {
        const list = [];
        for (let i = 0; i < devicesModel.count; i++)
            list.push(devicesModel.get(i));
        return list;
    }

    function _apply(state): void {
        root._available = state.available;
        root._enabled = state.enabled;
        root._adapter = state.adapter || "";
        root._busyId = state.busyId || "";
        devicesModel.clear();
        for (const device of state.devices || [])
            devicesModel.append(device);
    }

    function _requestFetch(): void {
        if (fetchProcess.running)
            return;
        fetchProcess.running = true;
    }

    function setEnabled(enabled: bool): void {
        if (!root._adapter)
            return;
        commandProcess.command = BluetoothParser.setEnabledCommand(root._adapter, enabled);
        commandProcess.running = true;
    }

    function toggleDevice(id: string): void {
        if (!id || id === root._busyId)
            return;
        let connected = false;
        for (let i = 0; i < devicesModel.count; i++) {
            if (devicesModel.get(i).id === id) {
                connected = devicesModel.get(i).connected;
                break;
            }
        }
        root._busyId = id;
        root._apply(BluetoothReducer.reduceFetch({
                available: root._available,
                enabled: root._enabled,
                adapter: root._adapter,
                busyId: root._busyId,
                devices: root._deviceList()
            }, {
                adapterPresent: root._available,
                adapter: root._adapter,
                enabled: root._enabled,
                devices: root._deviceList()
            }, 0));
        commandProcess.command = BluetoothParser.toggleDeviceCommand(id, !connected);
        commandProcess.running = true;
    }

    function openManager(): void {
        Quickshell.execDetached(BluetoothParser.openManagerCommand());
    }

    Component.onCompleted: root._requestFetch()
    Component.onDestruction: {
        pollTimer.stop();
        fetchProcess.running = false;
        commandProcess.running = false;
    }

    onDetailedMonitoringChanged: {
        pollTimer.restart();
        if (detailedMonitoring)
            root._requestFetch();
    }

    Process {
        id: fetchProcess
        command: ["sh", "-c", BluetoothParser.FETCH_COMMAND]
        stdout: StdioCollector {}
        onExited: exitCode => {
            const next = BluetoothReducer.reduceFetch({
                available: root._available,
                enabled: root._enabled,
                adapter: root._adapter,
                busyId: root._busyId,
                devices: root._deviceList()
            }, BluetoothParser.parseFetchOutput(stdout.text), exitCode);
            root._apply(next);
        }
    }

    Process {
        id: commandProcess
        stdout: StdioCollector {}
        onExited: {
            root._busyId = "";
            refreshDebounce.restart();
        }
    }

    Timer {
        id: refreshDebounce
        interval: 100
        repeat: false
        onTriggered: root._requestFetch()
    }

    Timer {
        id: pollTimer
        interval: root.detailedMonitoring ? 4000 : 20000
        running: true
        repeat: true
        onTriggered: root._requestFetch()
    }
}
