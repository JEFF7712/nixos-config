import QtQuick
import QtTest
import "../../../home/configs/quickshell/services/internal" as Internal

TestCase {
    name: "AudioModel"

    component FakeBackend: QtObject {
        property bool available: true
        property int volumePercent: 40
        property bool muted: false
        property var actions: []

        function setVolume(percent) {
            actions = actions.concat([
                {
                    name: "setVolume",
                    value: percent
                }
            ]);
        }

        function setMuted(value) {
            actions = actions.concat([
                {
                    name: "setMuted",
                    value: value
                }
            ]);
        }
    }

    component Harness: QtObject {
        property FakeBackend initialBackend: FakeBackend {}
        property FakeBackend replacementBackend: FakeBackend {
            available: true
            volumePercent: 73
            muted: true
        }
        property Internal.AudioModel model: Internal.AudioModel {
            backend: initialBackend
        }
        property QtObject consumerOne: QtObject {
            property var audioService: model
        }
        property QtObject consumerTwo: QtObject {
            property var audioService: model
        }
    }

    function createHarness() {
        const harness = createTemporaryObject(harnessComponent, this);
        verify(harness !== null);
        wait(0);
        return harness;
    }

    Component {
        id: harnessComponent
        Harness {}
    }

    function test_twoConsumersShareIdentityAndState() {
        const harness = createHarness();
        verify(harness.consumerOne.audioService === harness.consumerTwo.audioService);
        harness.model.setVolume(61);
        compare(harness.consumerOne.audioService.volumePercent, 61);
        compare(harness.consumerTwo.audioService.volumePercent, 61);
    }

    function test_setVolumeClampsRoutesAndStaysOptimistic() {
        const harness = createHarness();
        harness.model.setVolume(150);
        compare(harness.model.volumePercent, 100);
        compare(harness.initialBackend.volumePercent, 40);
        compare(harness.initialBackend.actions.length, 1);
        compare(harness.initialBackend.actions[0].name, "setVolume");
        compare(harness.initialBackend.actions[0].value, 100);

        harness.model.setVolume(-20);
        compare(harness.model.volumePercent, 0);
        compare(harness.initialBackend.actions[1].value, 0);
    }

    function test_adjustVolumeUsesTwoPercentSteps() {
        const harness = createHarness();
        harness.model.adjustVolume(1);
        compare(harness.model.volumePercent, 42);
        compare(harness.initialBackend.actions[0].value, 42);
        harness.model.adjustVolume(-1);
        compare(harness.model.volumePercent, 40);
        compare(harness.initialBackend.actions[1].value, 40);
        harness.model.adjustVolume(0);
        compare(harness.initialBackend.actions.length, 2);
    }

    function test_toggleMuteRoutesExactOptimisticValue() {
        const harness = createHarness();
        harness.model.toggleMute();
        verify(harness.model.muted);
        verify(!harness.initialBackend.muted);
        compare(harness.initialBackend.actions.length, 1);
        compare(harness.initialBackend.actions[0].name, "setMuted");
        compare(harness.initialBackend.actions[0].value, true);
    }

    function test_backendConfirmationReconcilesDifferentValues() {
        const harness = createHarness();
        harness.model.setVolume(80);
        harness.model.toggleMute();
        compare(harness.model.volumePercent, 80);
        verify(harness.model.muted);

        harness.initialBackend.volumePercent = 31;
        harness.initialBackend.muted = false;
        compare(harness.model.volumePercent, 31);
        verify(!harness.model.muted);
    }

    function test_unavailableRetainsLastValidStateAndRecovery() {
        const harness = createHarness();
        harness.initialBackend.available = false;
        verify(!harness.model.available);
        compare(harness.model.volumePercent, 40);
        verify(!harness.model.muted);

        harness.initialBackend.volumePercent = 68;
        harness.initialBackend.muted = true;
        compare(harness.model.volumePercent, 40);
        verify(!harness.model.muted);
        harness.initialBackend.available = true;
        verify(harness.model.available);
        compare(harness.model.volumePercent, 68);
        verify(harness.model.muted);
    }

    function test_unavailableActionsAreSafeNoOps() {
        const harness = createHarness();
        harness.initialBackend.available = false;
        harness.model.setVolume(80);
        harness.model.adjustVolume(1);
        harness.model.toggleMute();
        compare(harness.initialBackend.actions.length, 0);
        compare(harness.model.volumePercent, 40);
        verify(!harness.model.muted);
    }

    function test_fakeDefaultSinkReplacementRecovers() {
        const harness = createHarness();
        harness.initialBackend.available = false;
        verify(!harness.model.available);
        compare(harness.model.volumePercent, 40);

        harness.model.backend = harness.replacementBackend;
        verify(harness.model.available);
        compare(harness.model.volumePercent, 73);
        verify(harness.model.muted);
    }
}
