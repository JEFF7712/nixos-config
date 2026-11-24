pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Brightness, network, bluetooth, power and system as folio words, each with
// a sheet. `items` picks which a line shows; `above` opens sheets upward for
// BottomLine.
Row {
    id: row
    required property var window
    required property var screen
    readonly property real u: Theme.unit(screen)
    property real sheetX: 0
    property var items: ["brightness", "network", "bluetooth", "home", "power", "system"]
    property bool above: false
    function has(name: string): bool {
        return items.indexOf(name) !== -1;
    }
    spacing: 26 * u

    function show(name: string, item: Item): void {
        sheetX = item.mapToItem(null, item.width, 0).x;
        Machine.toggle(name, screen.name);
    }
    function shown(name: string): bool {
        return Machine.open === name && Machine.openScreen === screen.name;
    }
    function duration(seconds: real): string {
        if (!(seconds > 0))
            return "";
        const minutes = Math.round(seconds / 60);
        return minutes >= 60 ? Math.floor(minutes / 60) + "h " + (minutes % 60) + "m" : minutes + "m";
    }
    property string armed: ""
    function confirm(what: string, act): void {
        if (armed === what) {
            armed = "";
            act();
        } else {
            armed = what;
            disarm.restart();
        }
    }
    Timer {
        id: disarm
        interval: 3000
        onTriggered: row.armed = ""
    }
    readonly property var power: Machine.power
    readonly property bool charging: power.state === "charging" || power.state === "pending-charge" || power.state === "fully-charged"
    readonly property var profileWords: ({
            "power-saver": "saver",
            "balanced": "balanced",
            "performance": "performance"
        })

    component Word: Small {
        screen: row.screen
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }
    component Pick: Small {
        property bool chosen: false
        screen: row.screen
        link: true
        lit: chosen
        Rectangle {
            visible: parent.chosen
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -4
            width: parent.width
            height: 1
            color: Theme.fg
        }
    }
    component Panel: Sheet {
        id: panel
        required property string name
        anchor.window: row.window
        anchor.rect.x: Math.round(Math.max(8, Math.min(row.window.width - implicitWidth - 8, row.sheetX - implicitWidth)))
        anchor.rect.y: Math.round(row.above ? -implicitHeight - 6 * row.u : row.window.height + 2 * row.u)
        pad: 22 * row.u
        visible: row.has(name) && row.shown(name)
        onVisibleChanged: {
            if (!visible && Machine.open === name)
                Machine.open = "";
        }
    }

    Word {
        id: lumWord
        visible: row.has("brightness") && Machine.brightness.available
        link: true
        lit: row.shown("brightness")
        text: "lum " + Machine.brightness.averagePercent
        onPressed: row.show("brightness", lumWord)
        property real turned: 0
        onWheeled: event => {
            turned += event.angleDelta.y;
            const notches = turned > 0 ? Math.floor(turned / 120) : Math.ceil(turned / 120);
            turned -= notches * 120;
            for (let i = 0; i < Math.abs(notches); i++)
                Machine.brightness.adjustAll(notches > 0 ? 1 : -1);
        }
    }
    Word {
        id: netWord
        readonly property var net: Machine.network
        visible: row.has("network") && net.available
        link: true
        lit: net.connected || row.shown("network")
        text: (net.wiredConnected ? "wired" : net.connected ? net.activeSsid : net.wifiEnabled ? "offline" : "wifi off") + (net.vpnConnected ? " · vpn" : "")
        width: Math.min(implicitWidth, 220 * row.u)
        elide: Text.ElideRight
        onPressed: row.show("network", netWord)
    }
    Word {
        id: btWord
        readonly property var bt: Machine.bluetooth
        visible: row.has("bluetooth") && bt.available
        link: true
        lit: (bt.enabled && bt.connectedCount > 0) || row.shown("bluetooth")
        text: bt.enabled ? (bt.connectedCount > 0 ? "bt " + bt.connectedCount : "bt") : "bt off"
        onPressed: event => {
            if (event.button === Qt.MiddleButton)
                bt.setEnabled(!bt.enabled);
            else
                row.show("bluetooth", btWord);
        }
    }
    Word {
        id: homeWord
        readonly property var hass: Machine.home
        visible: row.has("home") && hass.configured
        link: true
        lit: hass.connected || row.shown("home")
        text: hass.connected ? "home" : "home " + (hass.phase === "idle" ? "off" : hass.phase)
        onPressed: event => {
            if (event.button === Qt.RightButton)
                hass.refresh();
            else
                row.show("home", homeWord);
        }
    }
    Word {
        id: batWord
        visible: row.has("power") && row.power.available
        link: true
        lit: row.charging || row.power.chargePercent > 20 || row.shown("power")
        color: !row.charging && row.power.chargePercent <= 10 ? Theme.signal : (lit ? Theme.fg : Theme.dim)
        text: "bat " + row.power.chargePercent + (row.charging ? "+" : "") + (row.power.profile === "balanced" || !row.profileWords[row.power.profile] ? "" : " · " + row.profileWords[row.power.profile])
        onPressed: event => {
            if (event.button === Qt.MiddleButton)
                row.power.cycleProfile(1);
            else
                row.show("power", batWord);
        }
        onWheeled: event => row.power.cycleProfile(event.angleDelta.y > 0 ? 1 : -1)
    }
    Word {
        id: sysWord
        visible: row.has("system") && Machine.system.available
        link: true
        lit: row.shown("system")
        text: "cpu " + Machine.system.cpuPercent
        onPressed: row.show("system", sysWord)
    }

    Panel {
        name: "brightness"
        Column {
            spacing: 14 * row.u
            Repeater {
                model: Machine.brightness.displays
                Row {
                    id: display
                    required property int index
                    required property string label
                    required property int percent
                    readonly property string displayId: Machine.brightness.displays.get(index)?.id ?? ""
                    spacing: 18 * row.u
                    Small {
                        screen: row.screen
                        lit: false
                        width: 200 * row.u
                        elide: Text.ElideRight
                        text: display.label
                    }
                    Repeater {
                        model: [5, 25, 50, 75, 100]
                        Pick {
                            required property int modelData
                            chosen: Math.abs(display.percent - modelData) < 3
                            text: modelData
                            onPressed: Machine.brightness.setBrightness(display.displayId, modelData)
                        }
                    }
                    Small {
                        screen: row.screen
                        width: 50 * row.u
                        horizontalAlignment: Text.AlignRight
                        text: display.percent
                    }
                }
            }
            Small {
                screen: row.screen
                lit: false
                text: "scroll the word to step"
            }
        }
    }

    Panel {
        name: "network"
        Column {
            spacing: 12 * row.u
            Row {
                spacing: 24 * row.u
                Pick {
                    visible: Machine.network.wifiAvailable
                    chosen: Machine.network.wifiEnabled
                    text: Machine.network.wifiEnabled ? "wifi on" : "wifi off"
                    onPressed: Machine.network.setWifiEnabled(!Machine.network.wifiEnabled)
                }
                Small {
                    screen: row.screen
                    link: true
                    lit: false
                    text: "settings"
                    onPressed: {
                        Machine.open = "";
                        Machine.network.openSettings();
                    }
                }
            }
            Small {
                visible: Machine.network.vpnConnected
                screen: row.screen
                lit: false
                text: "vpn " + Machine.network.vpnName + (Machine.network.vpnAddress ? " · " + Machine.network.vpnAddress : "")
            }
            Repeater {
                model: Machine.network.wiredConnections
                Pick {
                    required property string name
                    required property bool active
                    required property int index
                    chosen: active
                    text: "wired · " + name
                    onPressed: Machine.network.connectWired(Machine.network.wiredConnections.get(index).id)
                }
            }
            Repeater {
                model: Machine.network.networks
                Row {
                    id: net
                    required property int index
                    required property string ssid
                    required property int signal
                    required property bool active
                    required property bool known
                    visible: index < 10 && Machine.network.wifiEnabled
                    spacing: 18 * row.u
                    Pick {
                        width: 300 * row.u
                        elide: Text.ElideRight
                        chosen: net.active
                        text: net.ssid
                        onPressed: {
                            if (net.active)
                                return;
                            if (net.known)
                                Machine.network.connectKnown(net.ssid);
                            else
                                Machine.network.connectInteractive(net.ssid);
                        }
                    }
                    Small {
                        screen: row.screen
                        lit: false
                        width: 40 * row.u
                        horizontalAlignment: Text.AlignRight
                        text: net.signal
                    }
                    Small {
                        screen: row.screen
                        lit: false
                        text: net.known ? "saved" : ""
                    }
                }
            }
        }
    }

    Panel {
        name: "bluetooth"
        Column {
            spacing: 12 * row.u
            Row {
                spacing: 24 * row.u
                Pick {
                    chosen: Machine.bluetooth.enabled
                    text: Machine.bluetooth.enabled ? "bluetooth on" : "bluetooth off"
                    onPressed: Machine.bluetooth.setEnabled(!Machine.bluetooth.enabled)
                }
                Small {
                    screen: row.screen
                    link: true
                    lit: false
                    text: "manager"
                    onPressed: {
                        Machine.open = "";
                        Machine.bluetooth.openManager();
                    }
                }
            }
            Repeater {
                model: Machine.bluetooth.devices
                Row {
                    id: device
                    required property int index
                    required property string name
                    required property bool connected
                    required property bool busy
                    required property int batteryPercent
                    visible: Machine.bluetooth.enabled
                    spacing: 18 * row.u
                    Pick {
                        width: 300 * row.u
                        elide: Text.ElideRight
                        chosen: device.connected
                        opacity: device.busy ? 0.5 : 1
                        text: device.name
                        onPressed: Machine.bluetooth.toggleDevice(Machine.bluetooth.devices.get(device.index).id)
                    }
                    Small {
                        screen: row.screen
                        lit: false
                        text: device.batteryPercent >= 0 ? device.batteryPercent + "%" : ""
                    }
                }
            }
        }
    }

    Panel {
        name: "home"
        Column {
            spacing: 12 * row.u
            Row {
                spacing: 24 * row.u
                Small {
                    screen: row.screen
                    lit: Machine.home.connected
                    text: Machine.home.connected ? "home assistant" : "home assistant · " + Machine.home.phase
                }
                Small {
                    screen: row.screen
                    link: true
                    lit: false
                    text: Machine.home.connected ? "refresh" : "retry"
                    onPressed: Machine.home.connected ? Machine.home.refresh() : Machine.home.retryConnection()
                }
            }
            Small {
                visible: Machine.home.lastError.length > 0 && !Machine.home.connected
                screen: row.screen
                color: Theme.signal
                width: 420 * row.u
                wrapMode: Text.Wrap
                text: Machine.home.lastError
            }
            Repeater {
                model: {
                    Machine.home.stateRevision;
                    Machine.home.panelOrder;
                    return Machine.home.favoriteSummaries();
                }
                Row {
                    id: thing
                    required property var modelData
                    readonly property bool on: !modelData.roomReading && Machine.home.displayIsOn(modelData.entityId)
                    spacing: 18 * row.u
                    Pick {
                        width: 300 * row.u
                        elide: Text.ElideRight
                        chosen: thing.on
                        opacity: thing.modelData.available ? 1 : 0.5
                        text: thing.modelData.name
                        onPressed: {
                            if (!thing.modelData.roomReading && thing.modelData.available)
                                Machine.home.toggleEntity(thing.modelData.entityId);
                        }
                    }
                    Small {
                        screen: row.screen
                        lit: false
                        text: String(thing.modelData.state || "").toLowerCase()
                    }
                }
            }
        }
    }

    Panel {
        name: "power"
        Column {
            spacing: 14 * row.u
            Small {
                screen: row.screen
                text: "battery " + row.power.chargePercent + " · " + row.power.state.replace("-", " ") + (row.duration(row.power.secondsRemaining) ? " · " + row.duration(row.power.secondsRemaining) + (row.charging ? " to full" : " left") : "")
            }
            Small {
                screen: row.screen
                lit: false
                text: "draw " + row.power.drawWatts.toFixed(1) + " w" + (row.power.healthPercent > 0 ? " · health " + row.power.healthPercent : "")
            }
            Row {
                spacing: 24 * row.u
                Repeater {
                    model: ["power-saver", "balanced", "performance"]
                    Pick {
                        required property string modelData
                        chosen: row.power.profile === modelData
                        text: row.profileWords[modelData]
                        onPressed: row.power.setProfile(modelData)
                    }
                }
            }
            Row {
                spacing: 24 * row.u
                Pick {
                    visible: row.power.thresholdWritable
                    chosen: row.power.chargeLimit < 100
                    text: row.power.chargeLimit < 100 ? "limit " + row.power.chargeLimit : "limit off"
                    onPressed: row.power.toggleChargeLimit()
                }
                Pick {
                    chosen: row.power.idleInhibited
                    text: row.power.idleInhibited ? "stay awake" : "may sleep"
                    onPressed: row.power.toggleIdleInhibit()
                }
            }
            Small {
                visible: row.power.lastError.length > 0
                screen: row.screen
                color: Theme.signal
                text: row.power.lastError
            }
        }
    }

    Panel {
        name: "system"
        Column {
            spacing: 12 * row.u
            Small {
                screen: row.screen
                text: "cpu " + Machine.system.cpuPercent + " · mem " + Machine.system.ramUsedGiB.toFixed(1) + " g · disk " + Machine.system.diskPercent
            }
            Small {
                screen: row.screen
                lit: false
                text: Machine.system.hostName + " · " + Machine.system.kernel
            }
            Small {
                screen: row.screen
                lit: false
                text: "up " + Machine.system.uptime + (Machine.system.nixGeneration ? " · generation " + Machine.system.nixGeneration : "")
            }
            Row {
                spacing: 24 * row.u
                Pick {
                    text: "lock"
                    onPressed: {
                        Machine.open = "";
                        Machine.system.lock();
                    }
                }
                Pick {
                    text: "sleep"
                    onPressed: {
                        Machine.open = "";
                        Machine.system.suspend();
                    }
                }
                Pick {
                    chosen: row.armed === "restart"
                    text: chosen ? "restart?" : "restart"
                    onPressed: row.confirm("restart", () => Machine.system.reboot())
                }
                Pick {
                    chosen: row.armed === "shutdown"
                    text: chosen ? "shut down?" : "shut down"
                    onPressed: row.confirm("shutdown", () => Machine.system.powerOff())
                }
            }
        }
    }
}
