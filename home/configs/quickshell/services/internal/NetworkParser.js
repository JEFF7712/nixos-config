.pragma library

// Exact shell framing the current WifiPopup fetch owned: radio state, saved
// 802-11-wireless connection names, and the live AP scan, tagged by line
// prefix so a single combined process can report all three cheaply.
var FETCH_COMMAND = "echo \"radio|$(nmcli radio wifi 2>/dev/null)\";" + "nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2==\"802-11-wireless\"{print \"saved|\"$1}';" + "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi 2>/dev/null | awk -F: 'NF>=4 && $2!=\"\"{print \"net|\"$1\"|\"$2\"|\"$3\"|\"$4}'";

// Bar connectivity is a narrower, higher-cadence probe independent of the
// wifi popup's AP scan, matching the Topbar residual it replaces.
var GENERAL_COMMAND = "nmcli -t -f STATE general 2>/dev/null";

function radioToggleCommand(enabled) {
    return ["nmcli", "radio", "wifi", enabled ? "on" : "off"];
}

function connectKnownCommand(ssid) {
    return ["nmcli", "dev", "wifi", "connect", ssid];
}

function interactiveConnectArgv(ssid) {
    return ["kitty", "-e", "nmtui-connect", ssid];
}

function settingsArgv() {
    return ["kitty", "-e", "sudo", "nmtui"];
}

// Parses the combined radio|/saved|/net| framing described by FETCH_COMMAND.
// Returns raw (unmerged, undeduped) fields only; NetworkReducer.js owns
// dedup/sort/cap and role assignment.
function parseFetchOutput(text) {
    var lines = String(text || "").split("\n");
    var radioPresent = false;
    var radioEnabled = false;
    var saved = {};
    var rawNetworks = [];
    var activeSsid = "";
    var activeSignal = 0;
    var activeSecurity = "";

    for (var index = 0; index < lines.length; index++) {
        var line = lines[index].trim();
        if (!line)
            continue;
        if (line.indexOf("radio|") === 0) {
            var radioValue = line.substring(6);
            radioPresent = radioValue !== "";
            radioEnabled = radioValue === "enabled";
        } else if (line.indexOf("saved|") === 0) {
            saved[line.substring(6)] = true;
        } else if (line.indexOf("net|") === 0) {
            var fields = line.substring(4).split("|");
            var inUse = fields[0];
            var ssid = fields[1];
            var signal = parseInt(fields[2]) || 0;
            var securityField = fields[3] || "";
            var secure = securityField !== "" && securityField !== "--";
            if (inUse === "*") {
                activeSsid = ssid;
                activeSignal = signal;
                activeSecurity = secure ? securityField : "open";
            }
            rawNetworks.push({
                ssid: ssid,
                signal: signal,
                security: secure ? securityField : "open",
                secure: secure
            });
        }
    }

    return {
        radioPresent: radioPresent,
        radioEnabled: radioEnabled,
        saved: saved,
        rawNetworks: rawNetworks,
        activeSsid: activeSsid,
        activeSignal: activeSignal,
        activeSecurity: activeSecurity
    };
}

// Parses the single-line `nmcli -t -f STATE general` probe used for the bar
// connectivity pill. Any state other than the literal "connected" string
// nmcli reports (e.g. "connecting", "disconnected", "asleep") counts as not
// connected for the bar icon, matching current Topbar behavior.
function parseGeneralOutput(text) {
    var trimmed = String(text || "").trim();
    return {
        present: trimmed !== "",
        connected: trimmed === "connected"
    };
}
