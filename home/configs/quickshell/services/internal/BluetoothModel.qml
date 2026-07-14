import QtQuick
import Quickshell
import "BluetoothParser.js" as BluetoothParser
import "BluetoothReducer.js" as BluetoothReducer

Scope {
    id: root

    required property var backend
    // Kept for service/shell API stability; native Bluetooth is reactive.
    property bool detailedMonitoring: false

    property bool _available: false
    property bool _enabled: false
    property string _adapter: ""
    property string _busyId: ""
    property var _nativeById: ({})

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

    function _reconcile(): void {
        const observation = root.backend ? root.backend.observation : null;
        const live = (observation && observation.devices) || [];
        root._nativeById = {};
        for (const entry of live)
            root._nativeById[entry.id] = entry.native;

        const next = BluetoothReducer.reduceObservation({
            available: root._available,
            enabled: root._enabled,
            adapter: root._adapter,
            busyId: root._busyId,
            devices: root._deviceList()
        }, observation);
        root._apply(next);
    }

    function setEnabled(enabled: bool): void {
        if (root.backend)
            root.backend.setEnabled(enabled);
    }

    function toggleDevice(id: string): void {
        if (!id || id === root._busyId || !root.backend)
            return;
        const native = root._nativeById[id];
        if (!native)
            return;
        root._busyId = id;
        root._apply(BluetoothReducer.reduceObservation({
                available: root._available,
                enabled: root._enabled,
                adapter: root._adapter,
                busyId: root._busyId,
                devices: root._deviceList()
            }, root.backend.observation));
        root.backend.toggleDevice(native);
    }

    function openManager(): void {
        Quickshell.execDetached(BluetoothParser.openManagerCommand());
    }

    onBackendChanged: root._reconcile()
    Component.onCompleted: root._reconcile()

    property Connections _backendConnections: Connections {
        target: root.backend

        function onObservationChanged(): void {
            root._reconcile();
        }
    }
}
