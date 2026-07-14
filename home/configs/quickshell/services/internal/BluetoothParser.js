.pragma library

var FETCH_COMMAND = "a=$(busctl --system tree org.bluez 2>/dev/null | grep -oE '/org/bluez/hci[0-9]+' | head -1);" + "echo \"adapter|$a\";" + "[ -z \"$a\" ] && exit 0;" + "echo \"powered|$(busctl --system get-property org.bluez \"$a\" org.bluez.Adapter1 Powered 2>/dev/null | awk '{print $2}')\";" + "busctl --system tree org.bluez 2>/dev/null | grep -oE \"$a/dev_[A-F0-9_]+\" | sort -u | while read dev; do" + "  paired=$(busctl --system get-property org.bluez \"$dev\" org.bluez.Device1 Paired 2>/dev/null | awk '{print $2}');" + "  [ \"$paired\" != 'true' ] && continue;" + "  conn=$(busctl --system get-property org.bluez \"$dev\" org.bluez.Device1 Connected 2>/dev/null | awk '{print $2}');" + "  name=$(busctl --system get-property org.bluez \"$dev\" org.bluez.Device1 Alias 2>/dev/null | sed -E 's/^s \"(.*)\"$/\\1/');" + "  echo \"dev|$dev|$conn|$name\";" + "done";

function setEnabledCommand(adapter, enabled) {
    return ["busctl", "--system", "set-property", "org.bluez", adapter, "org.bluez.Adapter1", "Powered", "b", enabled ? "true" : "false"];
}

function toggleDeviceCommand(path, connect) {
    return ["busctl", "--system", "call", "org.bluez", path, "org.bluez.Device1", connect ? "Connect" : "Disconnect"];
}

function openManagerCommand() {
    return ["blueman-manager"];
}

function parseFetchOutput(text) {
    var lines = String(text || "").split("\n");
    var adapter = "";
    var powered = false;
    var devices = [];
    for (var index = 0; index < lines.length; index++) {
        var line = lines[index].trim();
        if (!line)
            continue;
        if (line.indexOf("adapter|") === 0)
            adapter = line.substring(8);
        else if (line.indexOf("powered|") === 0)
            powered = line.substring(8) === "true";
        else if (line.indexOf("dev|") === 0) {
            var fields = line.substring(4).split("|");
            devices.push({
                id: fields[0] || "",
                connected: fields[1] === "true",
                name: fields[2] || "Unknown"
            });
        }
    }
    return {
        adapterPresent: adapter !== "",
        adapter: adapter,
        enabled: powered,
        devices: devices
    };
}
