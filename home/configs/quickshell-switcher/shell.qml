import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property bool shown: false
    property var profiles: []
    property string activeProfile: ""
    property int focusedIndex: -1

    function open() {
        listProc.running = true;
        activeProc.running = true;
        shown = true;
    }
    function close() {
        shown = false;
        focusedIndex = -1;
    }
    function toggle() {
        if (shown)
            close();
        else
            open();
    }

    function activate(name) {
        // Detach with setsid -f and redirect all stdio so the child survives
        // switch-profile's pkill-quickshell and can't be killed by SIGPIPE.
        switchProc.command = ["bash", "-c", "setsid -f switch-profile \"$1\" </dev/null >/dev/null 2>&1", "--", name];
        switchProc.running = true;
        close();
    }

    IpcHandler {
        target: "profile"
        function toggle(): void {
            root.toggle();
        }
        function show(): void {
            root.open();
        }
        function hide(): void {
            root.close();
        }
    }

    Process {
        id: listProc
        command: ["sh", "-c", "for d in \"$HOME\"/.config/desktop-profiles/*/; do [ -d \"$d\" ] && basename \"$d\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(s => s.trim()).filter(s => s.length > 0);
                root.profiles = lines;
            }
        }
    }

    Process {
        id: activeProc
        command: ["sh", "-c", "cat \"$HOME\"/.config/desktop-profiles/active 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.activeProfile = text.trim();
            }
        }
    }

    Process {
        id: switchProc
        command: ["true"]
    }

    // One popup per screen: a lone PanelWindow only ever maps on a single
    // output, so Mod+P looked dead on every other monitor.
    Variants {
        model: Quickshell.screens

        ProfileSwitcher {
            property var modelData
            screen: modelData
            shown: root.shown
            profiles: root.profiles
            activeProfile: root.activeProfile
            focusedIndex: root.focusedIndex
            onCloseRequested: root.close()
            onFocusRequested: function (index) {
                root.focusedIndex = index;
            }
            onActivateRequested: function (name) {
                root.activate(name);
            }
        }
    }
}
