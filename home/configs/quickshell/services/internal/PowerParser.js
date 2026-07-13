.pragma library

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
}

function scalar(value) {
    var parsed = parseFloat(String(value));
    return isFinite(parsed) ? parsed : NaN;
}

function durationSeconds(value) {
    var match = String(value || "").trim().toLowerCase().match(/^([0-9]+(?:\.[0-9]+)?)\s+(seconds?|minutes?|hours?|days?)$/);
    if (!match)
        return 0;
    var amount = parseFloat(match[1]);
    var unit = match[2];
    if (unit.indexOf("day") === 0)
        return amount * 86400;
    if (unit.indexOf("hour") === 0)
        return amount * 3600;
    if (unit.indexOf("minute") === 0)
        return amount * 60;
    return amount;
}

function batteryState(value) {
    var normalized = String(value || "").trim().toLowerCase();
    if (normalized === "fully-charged" || normalized === "full")
        return "full";
    if (["charging", "discharging", "pending-charge", "pending-discharge"].indexOf(normalized) !== -1)
        return normalized;
    return "unknown";
}

function profileState(value) {
    var normalized = String(value || "").trim().toLowerCase();
    if (["power-saver", "balanced", "performance"].indexOf(normalized) !== -1)
        return normalized;
    return "unknown";
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

function reduceSnapshot(previous, text, exitCode) {
    if ((exitCode || 0) !== 0)
        return previous;
    var values = fields(text);
    if (values.snapshot !== "1")
        return previous;
    var next = copyState(previous);

    if (values.battery === "0") {
        next.available = false;
        next.chargePercent = 0;
        next.state = "unknown";
        next.secondsRemaining = 0;
        next.drawWatts = 0;
        next.healthPercent = 0;
    } else if (values.battery === "1") {
        var charge = scalar(String(values.charge || "").replace("%", ""));
        var draw = scalar(values.draw);
        var full = scalar(values.full);
        var design = scalar(values.design);
        if (isFinite(charge) && isFinite(draw) && isFinite(full) && isFinite(design)) {
            next.available = true;
            next.chargePercent = Math.round(clamp(charge, 0, 100));
            next.state = batteryState(values.state);
            next.secondsRemaining = durationSeconds(values.time);
            next.drawWatts = Math.max(0, draw);
            next.healthPercent = design > 0 ? Math.round(clamp(full * 100 / design, 0, 100)) : 0;
        }
    }

    if (values.profile !== undefined)
        next.profile = profileState(values.profile);

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
