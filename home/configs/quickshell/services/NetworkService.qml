import QtQuick
import Quickshell
import "internal" as Internal

Scope {
    id: root

    property bool scanningRequested: false

    readonly property bool available: model.available
    readonly property bool wifiEnabled: model.wifiEnabled
    readonly property bool connected: model.connected
    readonly property string activeSsid: model.activeSsid
    readonly property int activeSignal: model.activeSignal
    readonly property string activeSecurity: model.activeSecurity
    readonly property ListModel networks: model.networks

    function setWifiEnabled(enabled: bool): void {
        model.setWifiEnabled(enabled);
    }
    function connectKnown(ssid: string): void {
        model.connectKnown(ssid);
    }
    function connectInteractive(ssid: string): void {
        model.connectInteractive(ssid);
    }
    function openSettings(): void {
        model.openSettings();
    }

    Internal.NetworkBackend {
        id: backend
    }

    Internal.NetworkModel {
        id: model
        backend: backend
        scanningRequested: root.scanningRequested
    }
}
