import QtQuick
import QtTest
import "../../../home/configs/quickshell/PopupAnchor.js" as PopupAnchor

TestCase {
    name: "PopupAnchor"

    function test_centersOnPill() {
        compare(PopupAnchor.clampedLeft(500, 300, 1000, 10), 350);
    }

    function test_clampsToLeftBarEdge() {
        compare(PopupAnchor.clampedLeft(50, 300, 1000, 10), 10);
    }

    function test_clampsToRightBarEdge() {
        compare(PopupAnchor.clampedLeft(980, 300, 1000, 10), 690);
    }

    function test_noAnchorReturnsSentinel() {
        compare(PopupAnchor.clampedLeft(-1, 300, 1000, 10), -1);
    }

    function test_popupWiderThanBarStaysAtBarMargin() {
        compare(PopupAnchor.clampedLeft(500, 2000, 1000, 10), 10);
    }
}
