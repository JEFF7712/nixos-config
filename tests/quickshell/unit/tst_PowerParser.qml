import QtQuick
import QtTest
import "../../../home/configs/quickshell/services/internal/PowerParser.js" as PowerParser

TestCase {
    name: "PowerParser"

    function snapshot(overrides) {
        const values = {
            battery: "1",
            charge: "64%",
            state: "discharging",
            time: "2.5 hours",
            draw: "12.4 W",
            full: "52 Wh",
            design: "65 Wh",
            profile: "balanced",
            threshold: "80|1",
            stasis: "no"
        };
        for (const key in overrides || {})
            values[key] = overrides[key];
        return "snapshot|1\n" + "battery|" + values.battery + "\n" + "charge|" + values.charge + "\n" + "state|" + values.state + "\n" + "time|" + values.time + "\n" + "draw|" + values.draw + "\n" + "full|" + values.full + "\n" + "design|" + values.design + "\n" + "profile|" + values.profile + "\n" + "threshold|" + values.threshold + "\n" + "stasis|" + values.stasis + "\n";
    }

    function test_noBatteryNormalizesUnavailable() {
        const parsed = PowerParser.parseSnapshot(snapshot({
            battery: "0",
            charge: "",
            state: "",
            time: "",
            draw: "",
            full: "",
            design: "",
            threshold: "absent"
        }));
        verify(parsed !== null);
        verify(!parsed.available);
        compare(parsed.chargePercent, 0);
        compare(parsed.state, "unknown");
        compare(parsed.secondsRemaining, 0);
        compare(parsed.drawWatts, 0);
        compare(parsed.healthPercent, 0);
        compare(parsed.chargeLimit, 100);
        verify(!parsed.thresholdWritable);
    }

    function test_batteryStatesAndTimesNormalize() {
        const charging = PowerParser.parseSnapshot(snapshot({
            state: "charging",
            time: "45 minutes"
        }));
        compare(charging.state, "charging");
        compare(charging.secondsRemaining, 2700);
        compare(PowerParser.parseSnapshot(snapshot({
            state: "discharging"
        })).state, "discharging");
        compare(PowerParser.parseSnapshot(snapshot({
            state: "fully-charged",
            time: "unknown"
        })).state, "full");
        compare(PowerParser.parseSnapshot(snapshot({
            state: "pending-charge"
        })).state, "pending-charge");
        compare(PowerParser.parseSnapshot(snapshot({
            state: "pending-discharge"
        })).state, "pending-discharge");
    }

    function test_chargeRateHealthAndBoundsNormalize() {
        const parsed = PowerParser.parseSnapshot(snapshot({
            charge: "105%",
            draw: "8.75 W",
            full: "49.5 Wh",
            design: "60 Wh"
        }));
        compare(parsed.chargePercent, 100);
        compare(parsed.drawWatts, 8.75);
        compare(parsed.healthPercent, 83);
    }

    function test_profileEnumAndMissingDaemonNormalize() {
        compare(PowerParser.parseSnapshot(snapshot({
            profile: "power-saver"
        })).profile, "power-saver");
        compare(PowerParser.parseSnapshot(snapshot({
            profile: "balanced"
        })).profile, "balanced");
        compare(PowerParser.parseSnapshot(snapshot({
            profile: "performance"
        })).profile, "performance");
        compare(PowerParser.parseSnapshot(snapshot({
            profile: ""
        })).profile, "unknown");
        compare(PowerParser.parseSnapshot(snapshot({
            profile: "custom"
        })).profile, "unknown");
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
            charge: "72%",
            profile: "performance"
        }));
        compare(PowerParser.reduceSnapshot(previous, "not a snapshot"), previous);
        const batteryMalformed = PowerParser.reduceSnapshot(previous, snapshot({
            charge: "bad"
        }));
        compare(batteryMalformed.chargePercent, previous.chargePercent);
        compare(batteryMalformed.state, previous.state);
        compare(PowerParser.reduceSnapshot(previous, snapshot(), 1), previous);
    }

    function test_malformedBatteryDoesNotBlockOtherDomains() {
        const previous = PowerParser.parseSnapshot(snapshot({
            charge: "72%",
            profile: "balanced",
            threshold: "80|1",
            stasis: "no"
        }));
        const reduced = PowerParser.reduceSnapshot(previous, snapshot({
            charge: "bad",
            profile: "performance",
            threshold: "75|0",
            stasis: "yes"
        }));
        compare(reduced.chargePercent, 72);
        compare(reduced.profile, "performance");
        compare(reduced.chargeLimit, 75);
        verify(!reduced.thresholdWritable);
        verify(reduced.idleInhibited);
    }

    function test_malformedThresholdDoesNotBlockOtherDomains() {
        const previous = PowerParser.parseSnapshot(snapshot({threshold: "80|1"}));
        const reduced = PowerParser.reduceSnapshot(previous, snapshot({
            charge: "55%",
            state: "charging",
            profile: "power-saver",
            threshold: "invalid",
            stasis: "yes"
        }));
        compare(reduced.chargePercent, 55);
        compare(reduced.state, "charging");
        compare(reduced.profile, "power-saver");
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
}
