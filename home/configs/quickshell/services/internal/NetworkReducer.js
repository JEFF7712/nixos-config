.pragma library

function copyNetwork(network) {
    return {
        ssid: network.ssid,
        signal: network.signal,
        security: network.security,
        secure: network.secure,
        known: network.known,
        active: network.active,
        busy: !!network.busy
    };
}

// Dedup by strongest signal per SSID, sort desc, cap at 8.
function buildNetworkList(rawNetworks, saved, activeSsid) {
    var withRoles = (rawNetworks || []).map(function (entry) {
        return {
            ssid: entry.ssid,
            signal: entry.signal,
            security: entry.security,
            secure: entry.secure,
            known: !!(saved && saved[entry.ssid]) || entry.ssid === activeSsid,
            active: entry.ssid === activeSsid,
            busy: false
        };
    });
    withRoles.sort(function (a, b) {
        return b.signal - a.signal;
    });
    var seen = {};
    var deduped = [];
    for (var index = 0; index < withRoles.length; index++) {
        var network = withRoles[index];
        if (seen[network.ssid])
            continue;
        seen[network.ssid] = true;
        deduped.push(network);
        if (deduped.length >= 8)
            break;
    }
    return deduped;
}

function buildNetworkListFromNativeSnapshot(snapshot, activeSsid) {
    var raw = (snapshot || []).map(function (entry) {
        return {
            ssid: entry.ssid,
            signal: entry.signal,
            security: entry.security,
            secure: entry.secure
        };
    });
    var saved = {};
    (snapshot || []).forEach(function (entry) {
        if (entry.known)
            saved[entry.ssid] = true;
    });
    return buildNetworkList(raw, saved, activeSsid);
}

// Clear busy SSID once connected or gone from discovery.
function reconcileBusy(previousBusySsid, activeSsid, networks) {
    if (!previousBusySsid)
        return "";
    if (previousBusySsid === activeSsid)
        return "";
    var stillPresent = (networks || []).some(function (network) {
        return network.ssid === previousBusySsid;
    });
    return stillPresent ? previousBusySsid : "";
}

function applyBusyRole(networks, busySsid) {
    if (!busySsid)
        return (networks || []).map(copyNetwork);
    return (networks || []).map(function (network) {
        var copy = copyNetwork(network);
        copy.busy = copy.ssid === busySsid;
        return copy;
    });
}
