.pragma library

function copyDevice(device) {
    return {
        id: device.id,
        name: device.name,
        connected: !!device.connected,
        busy: !!device.busy
    };
}

function sortDevices(devices) {
    var list = (devices || []).map(copyDevice);
    list.sort(function (a, b) {
        if (a.connected !== b.connected)
            return b.connected - a.connected;
        return String(a.name).localeCompare(String(b.name));
    });
    return list;
}

function applyBusyRole(devices, busyId) {
    return sortDevices(devices).map(function (device) {
        device.busy = !!busyId && device.id === busyId;
        return device;
    });
}

function reconcileBusy(previousBusyId, devices) {
    if (!previousBusyId)
        return "";
    var stillPresent = (devices || []).some(function (device) {
        return device.id === previousBusyId;
    });
    return stillPresent ? previousBusyId : "";
}

function connectedCount(devices) {
    var count = 0;
    (devices || []).forEach(function (device) {
        if (device.connected)
            count++;
    });
    return count;
}

function reduceFetch(previous, parsed, exitCode) {
    var prev = previous || {
        available: false,
        enabled: false,
        devices: [],
        busyId: "",
        adapter: ""
    };
    if ((exitCode || 0) !== 0) {
        return {
            available: false,
            enabled: prev.enabled,
            devices: (prev.devices || []).map(copyDevice),
            busyId: prev.busyId || "",
            adapter: prev.adapter || ""
        };
    }
    if (!parsed || !parsed.adapterPresent) {
        return {
            available: false,
            enabled: false,
            devices: (prev.devices || []).map(copyDevice),
            busyId: prev.busyId || "",
            adapter: ""
        };
    }
    var devices = sortDevices(parsed.devices || []);
    var busyId = reconcileBusy(prev.busyId || "", devices);
    return {
        available: true,
        enabled: !!parsed.enabled,
        devices: applyBusyRole(devices, busyId),
        busyId: busyId,
        adapter: parsed.adapter || ""
    };
}

// Prefer native Connecting/Disconnecting flags. Keep an optimistic busyId
// while the device remains listed and has not yet reached the requested
// connected state; clear on disappearance or when the target state sticks.
function reconcileNativeBusy(previousBusyId, devices, wantConnected) {
    var byId = {};
    (devices || []).forEach(function (device) {
        byId[device.id] = device;
    });
    var nativeBusyId = "";
    (devices || []).forEach(function (device) {
        if (device.busy)
            nativeBusyId = device.id;
    });
    if (nativeBusyId)
        return nativeBusyId;
    if (!previousBusyId)
        return "";
    var current = byId[previousBusyId];
    if (!current)
        return "";
    if (typeof wantConnected === "boolean" && current.connected === wantConnected && !current.busy)
        return "";
    return previousBusyId;
}

function reduceObservation(previous, observation, wantConnected) {
    var prev = previous || {
        available: false,
        enabled: false,
        devices: [],
        busyId: "",
        adapter: ""
    };
    if (!observation || !observation.present) {
        return {
            available: false,
            enabled: prev.enabled,
            devices: (prev.devices || []).map(copyDevice),
            busyId: prev.busyId || "",
            adapter: prev.adapter || ""
        };
    }
    var incoming = observation.devices || [];
    // Retain the last paired list through transient empty churn while the
    // adapter stays present (mirrors Network discovery retention).
    var devices = (incoming.length === 0 && (prev.devices || []).length > 0)
        ? (prev.devices || []).map(copyDevice)
        : sortDevices(incoming);
    var busyId = reconcileNativeBusy(prev.busyId || "", devices, wantConnected);
    return {
        available: true,
        enabled: !!observation.enabled,
        devices: applyBusyRole(devices, busyId),
        busyId: busyId,
        adapter: observation.adapter || ""
    };
}
