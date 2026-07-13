import QtQuick
import QtTest
import "../../../home/configs/quickshell/services/internal/PowerParser.js" as PowerParser

TestCase {
    name: "PowerParser"

    function snapshot(overrides) {
        const values = {
            threshold: "80|1",
            stasis: "no"
        };
        for (const key in overrides || {})
            values[key] = overrides[key];
        return "snapshot|1\n" + "threshold|" + values.threshold + "\n" + "stasis|" + values.stasis + "\n";
    }

    function nativeBattery(overrides) {
        const observation = {
            ready: true,
            isPresent: true,
            isLaptopBattery: true,
            percentage: 0.64,
            stateValue: 2 // Discharging
            ,
            timeToEmpty: 9000,
            timeToFull: 0,
            changeRate: -12.4,
            healthPercentage: 80
        };
        for (const key in overrides || {})
            observation[key] = overrides[key];
        return observation;
    }

    function test_thresholdAbsentReadOnlyAndWritableNormalize() {
        const absent = PowerParser.parseSnapshot(snapshot({
            threshold: "absent"
        }));
        compare(absent.chargeLimit, 100);
        verify(!absent.thresholdWritable);

        const readOnly = PowerParser.parseSnapshot(snapshot({
            threshold: "80|0"
        }));
        compare(readOnly.chargeLimit, 80);
        verify(!readOnly.thresholdWritable);

        const writable = PowerParser.parseSnapshot(snapshot({
            threshold: "75|1"
        }));
        compare(writable.chargeLimit, 75);
        verify(writable.thresholdWritable);
    }

    function test_stasisStatesNormalizeAndMalformedPreservesLastValid() {
        const previous = PowerParser.parseSnapshot(snapshot({
            stasis: "yes"
        }));
        verify(previous.idleInhibited);
        verify(!PowerParser.parseSnapshot(snapshot({
            stasis: "no"
        })).idleInhibited);

        const reduced = PowerParser.reduceSnapshot(previous, snapshot({
            stasis: "unexpected"
        }));
        verify(reduced.idleInhibited);
        compare(reduced.lastError, "invalid stasis state");
    }

    function test_ownedActionErrorClearsOnSuccessfulDomainProbe() {
        const previous = PowerParser.parseSnapshot(snapshot());
        previous.thresholdError = "threshold action failed";
        previous.lastError = "threshold action failed";
        compare(PowerParser.reduceSnapshot(previous, snapshot()).lastError, "");

        const malformed = PowerParser.reduceSnapshot(previous, snapshot({
            stasis: "unexpected"
        }));
        compare(malformed.lastError, "invalid stasis state");
        compare(PowerParser.reduceSnapshot(malformed, snapshot()).lastError, "");
    }

    function test_malformedOrFailedSnapshotPreservesLastValid() {
        const previous = PowerParser.parseSnapshot(snapshot({
            threshold: "72|1"
        }));
        compare(PowerParser.reduceSnapshot(previous, "not a snapshot"), previous);
        compare(PowerParser.reduceSnapshot(previous, snapshot(), 1), previous);
    }

    function test_malformedThresholdDoesNotBlockStasis() {
        const previous = PowerParser.parseSnapshot(snapshot({
            threshold: "80|1"
        }));
        const reduced = PowerParser.reduceSnapshot(previous, snapshot({
            threshold: "invalid",
            stasis: "yes"
        }));
        compare(reduced.chargeLimit, 80);
        verify(reduced.thresholdWritable);
        verify(reduced.idleInhibited);
        compare(reduced.thresholdError, "invalid threshold state");
    }

    function test_adapterErrorsClearIndependently() {
        const previous = PowerParser.parseSnapshot(snapshot());
        const bothFailed = PowerParser.reduceSnapshot(previous, snapshot({
            threshold: "invalid",
            stasis: "invalid"
        }));
        compare(bothFailed.thresholdError, "invalid threshold state");
        compare(bothFailed.stasisError, "invalid stasis state");
        compare(bothFailed.lastError, "invalid threshold state");

        const thresholdRecovered = PowerParser.reduceSnapshot(bothFailed, snapshot({
            threshold: "75|1",
            stasis: "invalid"
        }));
        compare(thresholdRecovered.thresholdError, "");
        compare(thresholdRecovered.stasisError, "invalid stasis state");
        compare(thresholdRecovered.lastError, "invalid stasis state");

        const stasisRecoveredThresholdFailed = PowerParser.reduceSnapshot(thresholdRecovered, snapshot({
            threshold: "invalid",
            stasis: "yes"
        }));
        compare(stasisRecoveredThresholdFailed.thresholdError, "invalid threshold state");
        compare(stasisRecoveredThresholdFailed.stasisError, "");
        compare(stasisRecoveredThresholdFailed.lastError, "invalid threshold state");
    }

    function test_actionResultsUpdateOnlyTheirOwnedErrorDomain() {
        const bothFailed = {
            thresholdError: "invalid threshold state",
            stasisError: "invalid stasis state"
        };
        const stasisSucceeded = PowerParser.reduceAdapterResult(bothFailed, "stasis", true);
        compare(stasisSucceeded.thresholdError, "invalid threshold state");
        compare(stasisSucceeded.stasisError, "");
        compare(stasisSucceeded.lastError, "invalid threshold state");

        const thresholdFailed = PowerParser.reduceAdapterResult(stasisSucceeded, "threshold", false);
        compare(thresholdFailed.thresholdError, "threshold action failed");
        compare(thresholdFailed.stasisError, "");
        compare(thresholdFailed.lastError, "threshold action failed");

        const unrelated = PowerParser.reduceAdapterResult(thresholdFailed, "profile", true);
        compare(unrelated.thresholdError, "threshold action failed");
        compare(unrelated.stasisError, "");
    }

    function test_nativeBatteryStateNormalizesAllDesignStates() {
        compare(PowerParser.nativeBatteryState(0), "unknown"); // Unknown
        compare(PowerParser.nativeBatteryState(1), "charging"); // Charging
        compare(PowerParser.nativeBatteryState(2), "discharging"); // Discharging
        compare(PowerParser.nativeBatteryState(3), "unknown"); // Empty
        compare(PowerParser.nativeBatteryState(4), "full"); // FullyCharged
        compare(PowerParser.nativeBatteryState(5), "pending-charge"); // PendingCharge
        compare(PowerParser.nativeBatteryState(6), "pending-discharge"); // PendingDischarge
        compare(PowerParser.nativeBatteryState(7), "unknown");
        compare(PowerParser.nativeBatteryState(-1), "unknown");
        compare(PowerParser.nativeBatteryState(NaN), "unknown");
        compare(PowerParser.nativeBatteryState(undefined), "unknown");
    }

    function test_nativeProfileStateNormalizesAllProfiles() {
        compare(PowerParser.nativeProfileState(0), "power-saver");
        compare(PowerParser.nativeProfileState(1), "balanced");
        compare(PowerParser.nativeProfileState(2), "performance");
        compare(PowerParser.nativeProfileState(3), "unknown");
        compare(PowerParser.nativeProfileState(-1), "unknown");
        compare(PowerParser.nativeProfileState(NaN), "unknown");
    }

    function test_reduceNativeProfileNeverMarksUnavailable() {
        const previous = PowerParser.initialState();
        compare(PowerParser.reduceNativeProfile(previous, 0).profile, "power-saver");
        compare(PowerParser.reduceNativeProfile(previous, 1).profile, "balanced");
        compare(PowerParser.reduceNativeProfile(previous, 2).profile, "performance");
        compare(PowerParser.reduceNativeProfile(previous, 99).profile, "unknown");
    }

    function test_reduceNativeBatteryNormalizesValidObservation() {
        const previous = PowerParser.initialState();
        const reduced = PowerParser.reduceNativeBattery(previous, nativeBattery());
        verify(reduced.available);
        compare(reduced.chargePercent, 64);
        compare(reduced.state, "discharging");
        compare(reduced.secondsRemaining, 9000);
        compare(reduced.drawWatts, 12.4);
        compare(reduced.healthPercent, 80);
    }

    function test_reduceNativeBatteryPicksTimeToFullWhileCharging() {
        const previous = PowerParser.initialState();
        const reduced = PowerParser.reduceNativeBattery(previous, nativeBattery({
            stateValue: 1 // Charging
            ,
            timeToEmpty: 0,
            timeToFull: 2700,
            changeRate: 8.75
        }));
        compare(reduced.state, "charging");
        compare(reduced.secondsRemaining, 2700);
        compare(reduced.drawWatts, 8.75);
    }

    function test_reduceNativeBatteryPicksTimeToFullWhilePendingCharge() {
        const previous = PowerParser.initialState();
        const reduced = PowerParser.reduceNativeBattery(previous, nativeBattery({
            stateValue: 5 // PendingCharge
            ,
            timeToEmpty: 0,
            timeToFull: 1800
        }));
        compare(reduced.state, "pending-charge");
        compare(reduced.secondsRemaining, 1800);
    }

    function test_reduceNativeBatteryClampsPercentAndHealth() {
        const previous = PowerParser.initialState();
        const reduced = PowerParser.reduceNativeBattery(previous, nativeBattery({
            percentage: 1.2,
            healthPercentage: 130
        }));
        compare(reduced.chargePercent, 100);
        compare(reduced.healthPercent, 100);
    }

    function test_reduceNativeBatteryRetainsLastValidFieldsWhenTransientlyInvalid() {
        const previous = PowerParser.reduceNativeBattery(PowerParser.initialState(), nativeBattery());
        verify(previous.available);

        const notReady = PowerParser.reduceNativeBattery(previous, nativeBattery({
            ready: false
        }));
        verify(!notReady.available);
        compare(notReady.chargePercent, previous.chargePercent);
        compare(notReady.state, previous.state);
        compare(notReady.secondsRemaining, previous.secondsRemaining);
        compare(notReady.drawWatts, previous.drawWatts);
        compare(notReady.healthPercent, previous.healthPercent);

        const notPresent = PowerParser.reduceNativeBattery(previous, nativeBattery({
            isPresent: false
        }));
        verify(!notPresent.available);
        compare(notPresent.chargePercent, previous.chargePercent);

        const notLaptopBattery = PowerParser.reduceNativeBattery(previous, nativeBattery({
            isLaptopBattery: false
        }));
        verify(!notLaptopBattery.available);
        compare(notLaptopBattery.chargePercent, previous.chargePercent);

        const invalidPercentage = PowerParser.reduceNativeBattery(previous, nativeBattery({
            percentage: NaN
        }));
        verify(!invalidPercentage.available);
        compare(invalidPercentage.chargePercent, previous.chargePercent);

        const missingObservation = PowerParser.reduceNativeBattery(previous, undefined);
        verify(!missingObservation.available);
        compare(missingObservation.chargePercent, previous.chargePercent);
    }

    function test_reduceNativeBatteryDoesNotAffectAdapterFields() {
        const previous = PowerParser.reduceSnapshot(PowerParser.initialState(), snapshot({
            threshold: "75|1",
            stasis: "yes"
        }));
        const reduced = PowerParser.reduceNativeBattery(previous, nativeBattery());
        compare(reduced.chargeLimit, 75);
        verify(reduced.thresholdWritable);
        verify(reduced.idleInhibited);
    }
}
