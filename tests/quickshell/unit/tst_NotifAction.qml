import QtQuick
import QtTest
import "../../../home/configs/quickshell/NotifAction.js" as NotifAction

TestCase {
    name: "NotifAction"

    function test_usesProvidedText() {
        compare(NotifAction.label("Snooze", "default"), "Snooze");
    }

    function test_defaultWithEmptyTextIsOpen() {
        compare(NotifAction.label("", "default"), "Open");
        compare(NotifAction.label("  ", ""), "Open");
    }

    function test_activateAliasesAreOpen() {
        compare(NotifAction.label("", "activate"), "Open");
        compare(NotifAction.label("", "show"), "Open");
    }

    function test_inlineReply() {
        compare(NotifAction.label("", "inline-reply"), "Reply");
    }

    function test_humanizesBareIdentifier() {
        compare(NotifAction.label("", "open-in-browser"), "open in browser");
    }
}
