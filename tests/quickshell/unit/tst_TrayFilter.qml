import QtQuick
import QtTest
import "../../../home/configs/quickshell/TrayFilter.js" as TrayFilter

TestCase {
    name: "TrayFilter"

    function test_hidesNetworkManagerAndBlueman() {
        compare(TrayFilter.isHidden("nm-applet"), true);
        compare(TrayFilter.isHidden("nm_applet"), true);
        compare(TrayFilter.isHidden("blueman"), true);
        compare(TrayFilter.isHidden("blueman-tray"), true);
        compare(TrayFilter.isHidden("blueman-applet"), true);
    }

    function test_isCaseInsensitive() {
        compare(TrayFilter.isHidden("NM-Applet"), true);
        compare(TrayFilter.isHidden("BlueMan"), true);
    }

    function test_keepsOtherTrayApps() {
        compare(TrayFilter.isHidden("discord"), false);
        compare(TrayFilter.isHidden("steam"), false);
        compare(TrayFilter.isHidden(""), false);
        compare(TrayFilter.isHidden(null), false);
    }

    function test_visibleItemsDropsHiddenIds() {
        const kept = TrayFilter.visibleItems([
            {
                "id": "nm-applet"
            },
            {
                "id": "vesktop"
            },
            {
                "id": "blueman"
            }
        ]);
        compare(kept.length, 1);
        compare(kept[0].id, "vesktop");
    }
}
