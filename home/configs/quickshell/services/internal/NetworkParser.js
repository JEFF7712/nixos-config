.pragma library

// kitty subprocesses for nmtui escape hatches the native singleton cannot cover.
function interactiveConnectArgv(ssid) {
    return ["kitty", "-e", "nmtui-connect", ssid];
}

function settingsArgv() {
    return ["kitty", "-e", "nmtui"];
}
