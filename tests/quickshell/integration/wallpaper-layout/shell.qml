import QtQuick
import Quickshell
import "services" as Services

ShellRoot {
    id: root

    property int phase: 0
    property int observedResults: 0

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error(message);
            Qt.exit(1);
        }
    }

    Services.WallpaperLayout {
        id: placement
        screenName: "fixture"
        viewportWidth: 1440
        viewportHeight: 900
        candidates: [
            {
                name: "compact",
                width: 448,
                height: 648
            }
        ]
        enabled: true
        helperCommand: ["iris-python", Qt.resolvedUrl("helper.py").toString().replace(/^file:\/\//, "")]
        onResultChanged: {
            root.check(result.x !== 144, "Stale geometry was published");
            root.observedResults++;
        }
    }

    Timer {
        interval: 300
        running: true
        onTriggered: placement.viewportWidth = 1000
    }

    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (!placement.result)
                return;
            if (root.phase === 0) {
                root.check(placement.result.x === 100, "Latest geometry was not used");
                root.phase = 1;
                placement.viewportWidth = 1100;
            } else if (root.phase === 1 && placement.result.available === false) {
                root.check(placement.result.backdropOpacity === 1, "Invalid output did not select an opaque fallback");
                root.check(placement.result.x === 326, "Fallback geometry is incorrect");
                root.phase = 2;
                settled.start();
            }
        }
    }

    Timer {
        id: settled
        interval: 700
        onTriggered: {
            root.check(root.observedResults === 2, "Unexpected repeated analysis results");
            console.log("Wallpaper layout integration passed: stale output rejected, invalid output backed, no polling");
            Qt.quit();
        }
    }

    Timer {
        interval: 8000
        running: true
        onTriggered: {
            console.error("Wallpaper layout integration timed out");
            Qt.exit(1);
        }
    }
}
