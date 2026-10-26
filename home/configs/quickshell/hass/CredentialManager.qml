import QtQuick
import Quickshell.Io

// Serialized system-keyring adapter. It owns every short-lived plaintext copy
// of a token and never places one in argv. Service.qml decides whether the
// origin returned by a completed operation is still the active connection.
QtObject {
    id: root

    readonly property bool busy: writePending || clearPending || lookupPending || legacyPending

    property bool writePending: false
    property bool writeStarted: false
    property string writeToken: ""
    property string writeOrigin: ""

    property bool clearPending: false
    property bool clearStarted: false
    property string clearOrigin: ""

    property bool lookupPending: false
    property bool lookupStarted: false
    property string lookupOrigin: ""
    property string lookupToken: ""

    property bool legacyPending: false
    property bool legacyStarted: false
    property string legacyOrigin: ""
    property string legacyAttemptedFor: ""
    property bool legacyTokenSeen: false

    signal tokenReady(string token, string origin)
    signal cleared(string origin)
    signal failed(string message, string origin)

    function store(token, origin) {
        if (root.busy || !token || !origin) {
            root.failed("A keyring operation is already in progress.", origin || "");
            return false;
        }
        root.writeToken = String(token);
        root.writeOrigin = String(origin);
        root.writePending = true;
        root.writeStarted = false;
        storeProcess.command = ["secret-tool", "store", "--label=Home Assistant (Omarchy)", "service", "hass", "origin", root.writeOrigin];
        storeProcess.stdinEnabled = true;
        storeProcess.running = true;
        writeStartTimeout.restart();
        return true;
    }

    function clear(origin) {
        if (root.busy || !origin) {
            root.failed("A keyring operation is already in progress.", origin || "");
            return false;
        }
        root.clearOrigin = String(origin);
        root.clearPending = true;
        root.clearStarted = false;
        clearProcess.command = ["secret-tool", "clear", "service", "hass", "origin", root.clearOrigin];
        clearProcess.running = true;
        clearStartTimeout.restart();
        return true;
    }

    function lookup(origin) {
        if (root.busy || !origin)
            return false;
        root.lookupOrigin = String(origin);
        root.lookupToken = "";
        root.lookupPending = true;
        root.lookupStarted = false;
        lookupProcess.command = ["secret-tool", "lookup", "service", "hass", "origin", root.lookupOrigin];
        lookupProcess.running = true;
        lookupStartTimeout.restart();
        return true;
    }

    function startLegacyLookup(origin) {
        if (root.legacyAttemptedFor === origin) {
            root.failed("No access token stored for this Home Assistant origin.", origin);
            return;
        }
        root.legacyAttemptedFor = origin;
        root.legacyOrigin = origin;
        root.legacyTokenSeen = false;
        root.legacyPending = true;
        root.legacyStarted = false;
        legacyProcess.running = true;
        legacyStartTimeout.restart();
    }

    property Timer writeStartTimeout: Timer {
        interval: 5000
        onTriggered: {
            if (!root.writePending || root.writeStarted)
                return;
            var origin = root.writeOrigin;
            root.writeToken = "";
            root.writeOrigin = "";
            root.writePending = false;
            root.failed("Could not start secret-tool to store the token.", origin);
            if (storeProcess.running)
                storeProcess.signal(15);
        }
    }

    property Timer clearStartTimeout: Timer {
        interval: 5000
        onTriggered: {
            if (!root.clearPending || root.clearStarted)
                return;
            var origin = root.clearOrigin;
            root.clearOrigin = "";
            root.clearPending = false;
            root.failed("Could not start secret-tool to remove the token.", origin);
            if (clearProcess.running)
                clearProcess.signal(15);
        }
    }

    property Timer lookupStartTimeout: Timer {
        interval: 5000
        onTriggered: {
            if (!root.lookupPending || root.lookupStarted)
                return;
            var origin = root.lookupOrigin;
            root.lookupPending = false;
            root.failed("Could not start secret-tool to read the token.", origin);
            if (lookupProcess.running)
                lookupProcess.signal(15);
        }
    }

    property Timer legacyStartTimeout: Timer {
        interval: 5000
        onTriggered: {
            if (!root.legacyPending || root.legacyStarted)
                return;
            var origin = root.legacyOrigin;
            root.legacyPending = false;
            root.failed("Could not start secret-tool to check the legacy token.", origin);
            if (legacyProcess.running)
                legacyProcess.signal(15);
        }
    }

    property Process storeProcess: Process {
        command: []
        stdinEnabled: true
        onStarted: {
            if (!root.writePending) {
                storeProcess.signal(15);
                return;
            }
            root.writeStarted = true;
            writeStartTimeout.stop();
            storeProcess.write(root.writeToken + "\n");
            storeProcess.stdinEnabled = false;
        }
        onExited: function (exitCode) {
            if (!root.writePending)
                return;
            writeStartTimeout.stop();
            var token = root.writeToken;
            var origin = root.writeOrigin;
            root.writeToken = "";
            root.writeOrigin = "";
            root.writePending = false;
            root.writeStarted = false;
            if (exitCode !== 0) {
                root.failed("Could not write the token to the keyring.", origin);
                return;
            }
            root.legacyAttemptedFor = "";
            root.tokenReady(token, origin);
        }
    }

    property Process clearProcess: Process {
        command: []
        onStarted: {
            if (!root.clearPending) {
                clearProcess.signal(15);
                return;
            }
            root.clearStarted = true;
            clearStartTimeout.stop();
        }
        onExited: function (exitCode) {
            if (!root.clearPending)
                return;
            clearStartTimeout.stop();
            var origin = root.clearOrigin;
            root.clearOrigin = "";
            root.clearPending = false;
            root.clearStarted = false;
            // Exit 1 means no matching item; the desired state is already reached.
            if (exitCode !== 0 && exitCode !== 1) {
                root.failed("Could not remove the token from the keyring. Retry removal.", origin);
                return;
            }
            root.cleared(origin);
        }
    }

    property Process lookupProcess: Process {
        command: []
        stdout: SplitParser {
            onRead: function (value) {
                if (root.lookupPending && !root.lookupToken) {
                    root.lookupToken = String(value || "").trim();
                }
            }
        }
        onStarted: {
            if (!root.lookupPending) {
                lookupProcess.signal(15);
                return;
            }
            root.lookupStarted = true;
            lookupStartTimeout.stop();
        }
        onExited: function (exitCode) {
            if (!root.lookupPending)
                return;
            lookupStartTimeout.stop();
            var origin = root.lookupOrigin;
            root.lookupPending = false;
            root.lookupStarted = false;
            var token = exitCode === 0 ? root.lookupToken : "";
            root.lookupToken = "";
            if (token)
                root.tokenReady(token, origin);
            else
                root.startLegacyLookup(origin);
        }
    }

    property Process legacyProcess: Process {
        command: ["secret-tool", "lookup", "service", "hass", "account", "token"]
        stdout: SplitParser {
            onRead: function (value) {
                if (root.legacyPending && String(value || "").trim()) {
                    root.legacyTokenSeen = true;
                }
            }
        }
        onStarted: {
            if (!root.legacyPending) {
                legacyProcess.signal(15);
                return;
            }
            root.legacyStarted = true;
            legacyStartTimeout.stop();
        }
        onExited: function (exitCode) {
            if (!root.legacyPending)
                return;
            legacyStartTimeout.stop();
            var origin = root.legacyOrigin;
            root.legacyPending = false;
            root.legacyStarted = false;
            var exists = exitCode === 0 && root.legacyTokenSeen;
            root.legacyTokenSeen = false;
            // These state the condition only. Telling the reader to open settings
            // belongs to the surface that isn't settings — see Panel.qml.
            root.failed(exists ? "A legacy unscoped token exists. Re-enter it to bind it to this Home Assistant origin." : "No access token stored for this Home Assistant origin.", origin);
        }
    }
}
