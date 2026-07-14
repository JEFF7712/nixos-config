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
