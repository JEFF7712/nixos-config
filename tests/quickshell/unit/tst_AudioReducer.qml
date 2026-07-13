import QtQuick
import QtTest
import "../../../home/configs/quickshell/services/internal/AudioReducer.js" as AudioReducer

TestCase {
    name: "AudioReducer"

    readonly property var initial: ({available: false, volumePercent: 25, muted: true})

    function observation(overrides) {
        const value = {
            backendReady: true,
            targetPresent: true,
            targetReady: true,
            controlsPresent: true,
            volume: 0.425,
            muted: false
        };
        Object.assign(value, overrides || {});
        return value;
    }

    function test_roundsAndClampsPercent() {
        compare(AudioReducer.reduce(initial, observation({volume: 0.425})).volumePercent, 43);
        compare(AudioReducer.reduce(initial, observation({volume: -0.2})).volumePercent, 0);
        compare(AudioReducer.reduce(initial, observation({volume: 1.2})).volumePercent, 100);
    }

    function test_readsMuteAndReadyTarget() {
        const state = AudioReducer.reduce(initial, observation({volume: 0.6, muted: true}));
        verify(state.available);
        compare(state.volumePercent, 60);
        verify(state.muted);
    }

    function test_unavailableInputsRetainLastValidState_data() {
        return [
            {tag: "backend-not-ready", overrides: {backendReady: false}},
            {tag: "null-target", overrides: {targetPresent: false}},
            {tag: "unready-target", overrides: {targetReady: false}},
            {tag: "missing-controls", overrides: {controlsPresent: false}},
            {tag: "invalid-volume-nan", overrides: {volume: NaN}},
            {tag: "invalid-volume-infinity", overrides: {volume: Infinity}}
        ];
    }

    function test_unavailableInputsRetainLastValidState(data) {
        const state = AudioReducer.reduce(initial, observation(data.overrides));
        verify(!state.available);
        compare(state.volumePercent, 25);
        verify(state.muted);
    }

    function test_recoversAfterUnavailableTarget() {
        const unavailable = AudioReducer.reduce(initial, observation({targetPresent: false}));
        const recovered = AudioReducer.reduce(unavailable, observation({volume: 0.81, muted: false}));
        verify(recovered.available);
        compare(recovered.volumePercent, 81);
        verify(!recovered.muted);
    }
}
