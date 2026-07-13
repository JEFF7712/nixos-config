.pragma library

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
}

function scalar(value) {
    var parsed = parseFloat(String(value));
    return isFinite(parsed) ? parsed : NaN;
}

function fields(text) {
    var result = {};
    var lines = String(text || "").split("\n");
    for (var index = 0; index < lines.length; index++) {
        var separator = lines[index].indexOf("|");
        if (separator < 0)
            continue;
        var key = lines[index].substring(0, separator).trim();
        result[key] = lines[index].substring(separator + 1).trim();
    }
    return result;
}

function initialState() {
    return {
        available: false,
        chargePercent: 0,
        state: "unknown",
        secondsRemaining: 0,
        drawWatts: 0,
        healthPercent: 0,
        profile: "unknown",
        chargeLimit: 100,
        thresholdWritable: false,
        idleInhibited: false,
        thresholdError: "",
        stasisError: "",
        lastError: ""
    };
}

function copyState(previous) {
    var base = previous || initialState();
    return {
        available: base.available,
        chargePercent: base.chargePercent,
        state: base.state,
        secondsRemaining: base.secondsRemaining,
        drawWatts: base.drawWatts,
        healthPercent: base.healthPercent,
        profile: base.profile,
        chargeLimit: base.chargeLimit,
        thresholdWritable: base.thresholdWritable,
        idleInhibited: base.idleInhibited,
        thresholdError: base.thresholdError || "",
        stasisError: base.stasisError || "",
        lastError: base.lastError || ""
    };
}

function reduceAdapterResult(previous, domain, succeeded) {
    var errors = {
        thresholdError: previous.thresholdError || "",
        stasisError: previous.stasisError || ""
    };
    if (domain === "threshold")
        errors.thresholdError = succeeded ? "" : "threshold action failed";
    else if (domain === "stasis")
        errors.stasisError = succeeded ? "" : "stasis action failed";
    errors.lastError = errors.thresholdError || errors.stasisError;
    return errors;
}

// Narrow adapter snapshot: covers only the threshold and stasis subprocess
// adapters this service still owns. Battery and profile state come from the
// native UPower/PowerProfiles backend (see reduceNativeBattery/reduceNativeProfile).
function reduceSnapshot(previous, text, exitCode) {
    if ((exitCode || 0) !== 0)
        return previous;
    var values = fields(text);
    if (values.snapshot !== "1")
        return previous;
    var next = copyState(previous);

    if (values.threshold === "absent") {
        next.chargeLimit = 100;
        next.thresholdWritable = false;
        next.thresholdError = "";
    } else {
        var threshold = String(values.threshold || "").split("|");
        var parsedLimit = scalar(threshold[0]);
        if (threshold.length === 2 && isFinite(parsedLimit) && (threshold[1] === "0" || threshold[1] === "1")) {
            next.chargeLimit = Math.round(clamp(parsedLimit, 0, 100));
            next.thresholdWritable = threshold[1] === "1";
            next.thresholdError = "";
        } else {
            next.thresholdError = "invalid threshold state";
        }
    }

    if (values.stasis === "yes") {
        next.idleInhibited = true;
        next.stasisError = "";
    } else if (values.stasis === "no") {
        next.idleInhibited = false;
        next.stasisError = "";
    } else {
        next.stasisError = "invalid stasis state";
    }

    next.lastError = next.thresholdError || next.stasisError;
    return next;
}

function parseSnapshot(text, exitCode) {
    if ((exitCode || 0) !== 0 || fields(text).snapshot !== "1")
        return null;
    return reduceSnapshot(initialState(), text, exitCode);
}

// Native UPower/PowerProfiles enum normalization ---------------------------
//
// Quickshell.Services.UPower exposes UPowerDeviceState::Enum and
// PowerProfile::Enum as plain integers in QML. Their values are stable
// (declared explicitly in the Quickshell C++ headers), so normalization can
// be done with a pure lookup table, independent of any QML/Quickshell import.

var DEVICE_STATE_NAMES = [
    "unknown", // UPowerDeviceState.Unknown = 0
    "charging", // UPowerDeviceState.Charging = 1
    "discharging", // UPowerDeviceState.Discharging = 2
    "unknown", // UPowerDeviceState.Empty = 3 (no design state for depleted-but-idle)
    "full", // UPowerDeviceState.FullyCharged = 4
    "pending-charge", // UPowerDeviceState.PendingCharge = 5
    "pending-discharge" // UPowerDeviceState.PendingDischarge = 6
];

var PROFILE_NAMES = [
    "power-saver", // PowerProfile.PowerSaver = 0
    "balanced", // PowerProfile.Balanced = 1
    "performance" // PowerProfile.Performance = 2
];

function nativeBatteryState(value) {
    var index = Math.trunc(Number(value));
    if (!isFinite(index) || index < 0 || index >= DEVICE_STATE_NAMES.length)
        return "unknown";
    return DEVICE_STATE_NAMES[index];
}

function nativeProfileState(value) {
    var index = Math.trunc(Number(value));
    if (!isFinite(index) || index < 0 || index >= PROFILE_NAMES.length)
        return "unknown";
    return PROFILE_NAMES[index];
}

// Reduces a native battery observation (from the UPower backend) into the
// public battery fields, retaining the last valid reading whenever the
// snapshot is transiently invalid (device not ready, absent, or not a
// laptop battery) instead of resetting to zero/unknown.
function reduceNativeBattery(previous, observation) {
    var next = copyState(previous);
    var obs = observation || {};
    var valid = obs.ready === true && obs.isPresent === true && obs.isLaptopBattery === true && typeof obs.percentage === "number" && isFinite(obs.percentage);

    if (!valid) {
        next.available = false;
        return next;
    }

    var state = nativeBatteryState(obs.stateValue);
    var timeToEmpty = Math.max(0, scalar(obs.timeToEmpty) || 0);
    var timeToFull = Math.max(0, scalar(obs.timeToFull) || 0);
    var usesChargeTime = state === "charging" || state === "pending-charge";

    next.available = true;
    next.chargePercent = Math.round(clamp(obs.percentage * 100, 0, 100));
    next.state = state;
    next.secondsRemaining = usesChargeTime ? timeToFull : timeToEmpty;
    next.drawWatts = Math.abs(scalar(obs.changeRate) || 0);
    next.healthPercent = Math.round(clamp(scalar(obs.healthPercentage) || 0, 0, 100));
    return next;
}

// PowerProfiles has no availability property and defaults to Balanced before
// power-profiles-daemon responds (or if it is absent entirely), so this
// reducer never marks profile state as unavailable; it only normalizes.
function reduceNativeProfile(previous, profileValue) {
    var next = copyState(previous);
    next.profile = nativeProfileState(profileValue);
    return next;
}
