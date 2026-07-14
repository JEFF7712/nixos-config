.pragma library

// The native Networking backend owns radio, scan, and connect state
// directly; kitty is the only subprocess this domain still owns, for the
// two interactive escape hatches the native singleton cannot cover itself.
function interactiveConnectArgv(ssid) {
    return ["kitty", "-e", "nmtui-connect", ssid];
}

function settingsArgv() {
    return ["kitty", "-e", "sudo", "nmtui"];
}
