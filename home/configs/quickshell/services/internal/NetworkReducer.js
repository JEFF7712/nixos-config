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

// Dedups by strongest signal per SSID, sorts descending, and caps the
// result at eight entries — the exact discovery-list behavior this service
// has always centralized. `saved` is a plain ssid->true lookup; a network
// counts as known if it has a saved connection or is the currently active
// SSID (mirrors the pre-native "saved" role).
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

// Adapts a native-shaped snapshot (each entry already carrying its own
// `known` flag straight from the native Network object, rather than a
// separate saved-connections lookup) into the same dedup/sort/cap pipeline
// buildNetworkList has always owned, so both backends share one reducer.
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

// A busy SSID clears once it becomes the active connection or disappears
// from the current discovery list (connect failed/network went out of
// range) — matches the prior WifiPopup busySsid clearing rule exactly.
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
