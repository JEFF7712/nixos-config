import QtQuick
import QtTest
import "../../../home/configs/quickshell/services/internal/MediaParser.js" as MediaParser

TestCase {
    name: "MediaParser"

    function complete(overrides) {
        const value = {
            record: true,
            status: "Playing",
            title: "Song",
            artist: "Artist",
            album: "Album",
            artUrl: "file:///cover.png",
            position: "12.5",
            length: "90000000",
            shuffle: "On",
            loop: "Playlist",
            volume: "0.75",
            volumeSupported: true
        };
        for (const key in overrides || {})
            value[key] = overrides[key];
        return JSON.stringify(value);
    }

    function test_validCompleteSnapshot() {
        const parsed = MediaParser.parseSnapshot(complete());
        verify(parsed !== null);
        verify(parsed.available);
        verify(parsed.playing);
        compare(parsed.positionSeconds, 12.5);
        compare(parsed.lengthSeconds, 90);
        verify(parsed.shuffleEnabled);
        compare(parsed.loopMode, "Playlist");
        compare(parsed.playerVolume, 0.75);
        verify(parsed.volumeIsPlayer);
    }

    function test_preservesArbitraryMetadata() {
        const title = "before@@@after\nslash\\snowman ☃ 音楽";
        const parsed = MediaParser.parseSnapshot(complete({
            title: title
        }));
        compare(parsed.title, title);
    }

    function test_rejectsMissingAndAcceptsExtraFields() {
        const missing = JSON.parse(complete());
        delete missing.album;
        compare(MediaParser.parseSnapshot(JSON.stringify(missing)), null);
        verify(MediaParser.parseSnapshot(complete({
            extra: "ignored"
        })) !== null);
    }

    function test_rejectsEmptyMalformedAndTruncatedJson() {
        compare(MediaParser.parseSnapshot(""), null);
        compare(MediaParser.parseSnapshot("not json"), null);
        compare(MediaParser.parseSnapshot('{"record":true'), null);
    }

    function test_nonzeroAndNoRecordAreUnavailable() {
        compare(MediaParser.parseSnapshot(complete(), 1), null);
        compare(MediaParser.parseSnapshot(complete({
            record: false
        })), null);
    }

    function test_normalizesNumbersBooleansLoopAndStatus() {
        const parsed = MediaParser.parseSnapshot(complete({
            status: "Paused",
            position: "nope",
            length: "-2",
            shuffle: "off",
            loop: "invalid",
            volume: "1.7",
            volumeSupported: "false"
        }));
        verify(!parsed.playing);
        compare(parsed.status, "Paused");
        compare(parsed.positionSeconds, 0);
        compare(parsed.lengthSeconds, 0);
        verify(!parsed.shuffleEnabled);
        compare(parsed.loopMode, "None");
        compare(parsed.playerVolume, 1);
        verify(!parsed.volumeIsPlayer);
    }

    function test_unknownStatusNormalizesToStopped() {
        const parsed = MediaParser.parseSnapshot(complete({
            status: "surprise"
        }));
        compare(parsed.status, "Stopped");
        verify(!parsed.playing);
    }

    function test_volumeRouteKeepsSystemFallbackBackendFree() {
        compare(MediaParser.volumeRoute(true, true), "player");
        compare(MediaParser.volumeRoute(true, false), "player");
        compare(MediaParser.volumeRoute(false, true), "system");
        compare(MediaParser.volumeRoute(false, false), "none");
    }
}
