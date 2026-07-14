.pragma library

function initialState() {
    return {
        available: false,
        wifiEnabled: false,
        connected: false,
        activeSsid: "",
        activeSignal: 0,
        activeSecurity: "",
        networks: [],
        busySsid: ""
    };
}

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

function copyState(previous) {
    var base = previous || initialState();
    return {
        available: base.available,
        wifiEnabled: base.wifiEnabled,
        connected: base.connected,
        activeSsid: base.activeSsid,
        activeSignal: base.activeSignal,
        activeSecurity: base.activeSecurity,
        networks: (base.networks || []).map(copyNetwork),
        busySsid: base.busySsid || ""
    };
}

// Dedups by strongest signal per SSID, sorts descending, and caps the
// result at eight entries — the exact WifiPopup fetchProc behavior this
// service centralizes. `saved` is a plain ssid->true lookup (802-11-wireless
// connection names); a network counts as known if it has a saved connection
// or is the currently active SSID (mirrors the pre-migration "saved" role).
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

// A failed or malformed fetch (networking daemon absent, non-zero exit)
// preserves the last known list/active-network fields instead of blanking
// them, and marks `available` false so views can distinguish "no data yet"
// from "no networks in range". Recovery happens through the next successful
// poll on the normal cadence — no separate reload/backoff machinery.
function reduceFetch(previous, parsed, exitCode) {
    var next = copyState(previous);
    if ((exitCode || 0) !== 0 || !parsed || !parsed.radioPresent) {
        next.available = false;
        return next;
    }
    next.available = true;
    next.wifiEnabled = parsed.radioEnabled;
    next.activeSsid = parsed.activeSsid;
    next.activeSignal = parsed.activeSignal;
    next.activeSecurity = parsed.activeSecurity;
    next.networks = buildNetworkList(parsed.rawNetworks, parsed.saved, parsed.activeSsid);
    return next;
}

// The bar connectivity probe is independent of the AP-scan cadence and
// fails/succeeds on its own; a failed read leaves the last known value.
function reduceGeneral(previous, parsed, exitCode) {
    var next = copyState(previous);
    if ((exitCode || 0) !== 0 || !parsed || !parsed.present)
        return next;
    next.connected = parsed.connected;
    return next;
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
