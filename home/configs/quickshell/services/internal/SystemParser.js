.pragma library

var MARK_MEM = "###QS-MEM###";

var METRICS_COMMAND = "cat /proc/stat 2>/dev/null; " + "printf '\\n%s\\n' '" + MARK_MEM + "'; " + "cat /proc/meminfo 2>/dev/null";
var DISK_COMMAND = "df -P / 2>&1";

// Uptime from /proc/uptime so a missing `uptime -p` cannot blank the probe.
var METADATA_COMMAND = "echo \"host|$(hostnamectl hostname 2>/dev/null || hostname)\"; " + "echo \"kernel|$(uname -r)\"; " + "echo \"uptime|$(awk '{print int($1)}' /proc/uptime 2>/dev/null)\"; " + "g=$(readlink /nix/var/nix/profiles/system 2>/dev/null | grep -o '[0-9]*' | head -1); " + "[ -n \"$g\" ] && echo \"gen|$g\" || true";

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
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

// Pretty-print /proc/uptime seconds; non-numeric strings pass through.
function formatUptime(raw) {
    var text = String(raw || "").trim();
    if (!text)
        return "";
    if (!/^\d+(\.\d+)?$/.test(text))
        return text;
    var seconds = Math.floor(Number(text));
    if (!isFinite(seconds) || seconds < 0)
        return "";
    var days = Math.floor(seconds / 86400);
    var hours = Math.floor((seconds % 86400) / 3600);
    var minutes = Math.floor((seconds % 3600) / 60);
    var parts = [];
    if (days > 0)
        parts.push(days + (days === 1 ? " day" : " days"));
    if (hours > 0)
        parts.push(hours + (hours === 1 ? " hour" : " hours"));
    if (minutes > 0 || parts.length === 0)
        parts.push(minutes + (minutes === 1 ? " minute" : " minutes"));
    return parts.join(", ");
}

function initialState() {
    return {
        available: false,
        cpuPercent: 0,
        ramUsedGiB: 0,
        ramPercent: 0,
        diskPercent: 0,
        hostName: "",
        kernel: "",
        uptime: "",
        nixGeneration: "",
        lastError: "",
        cpuUsedTotal: null,
        cpuOverallTotal: null
    };
}

function copyState(previous) {
    var base = previous || initialState();
    return {
        available: base.available,
        cpuPercent: base.cpuPercent,
        ramUsedGiB: base.ramUsedGiB,
        ramPercent: base.ramPercent,
        diskPercent: base.diskPercent,
        hostName: base.hostName,
        kernel: base.kernel,
        uptime: base.uptime,
        nixGeneration: base.nixGeneration,
        lastError: base.lastError || "",
        cpuUsedTotal: base.cpuUsedTotal === undefined ? null : base.cpuUsedTotal,
        cpuOverallTotal: base.cpuOverallTotal === undefined ? null : base.cpuOverallTotal
    };
}

// Parses one aggregate "cpu " line from a /proc/stat snapshot into the
// user+system "used" total and the user+nice+system+idle "total", matching
// the previous Topbar awk script's field selection.
function parseCpuTotals(text) {
    var lines = String(text || "").split("\n");
    for (var index = 0; index < lines.length; index++) {
        var match = lines[index].match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
        if (!match)
            continue;
        var user = Number(match[1]);
        var nice = Number(match[2]);
        var system = Number(match[3]);
        var idle = Number(match[4]);
        return {
            used: user + system,
            total: user + nice + system + idle
        };
    }
    return null;
}

function computeCpuPercent(previousUsed, previousTotal, current) {
    if (previousUsed === null || previousTotal === null || !current)
        return null;
    var deltaTotal = current.total - previousTotal;
    var deltaUsed = current.used - previousUsed;
    if (deltaTotal <= 0)
        return null;
    if (deltaUsed < 0)
        return null;
    return Math.round(clamp(deltaUsed * 100 / deltaTotal, 0, 100));
}

function parseMemInfo(text) {
    var total = null;
    var available = null;
    var lines = String(text || "").split("\n");
    for (var index = 0; index < lines.length; index++) {
        var totalMatch = lines[index].match(/^MemTotal:\s+(\d+)/);
        if (totalMatch)
            total = Number(totalMatch[1]);
        var availableMatch = lines[index].match(/^MemAvailable:\s+(\d+)/);
        if (availableMatch)
            available = Number(availableMatch[1]);
    }
    if (total === null || available === null || total <= 0)
        return null;
    var usedKiB = Math.max(0, total - available);
    return {
        ramUsedGiB: usedKiB / 1048576,
        ramPercent: Math.round(clamp(usedKiB * 100 / total, 0, 100))
    };
}

function parseDiskPercent(text) {
    var lines = String(text || "").trim().split("\n");
    if (lines.length < 2)
        return null;
    var columns = lines[1].trim().split(/\s+/);
    if (columns.length < 5)
        return null;
    var match = columns[4].match(/^(\d+)%?$/);
    if (!match)
        return null;
    return Math.round(clamp(Number(match[1]), 0, 100));
}

function splitMetricsText(text) {
    var raw = String(text || "");
    var memSplit = raw.indexOf(MARK_MEM);
    if (memSplit < 0)
        return null;
    return {
        cpu: raw.substring(0, memSplit),
        meminfo: raw.substring(memSplit + MARK_MEM.length)
    };
}

function reduceMetricsSnapshot(previous, text, exitCode) {
    if ((exitCode || 0) !== 0)
        return copyState(previous);
    var segments = splitMetricsText(text);
    var next = copyState(previous);
    if (!segments) {
        next.lastError = "failed to parse metrics snapshot";
        return next;
    }

    var failures = [];

    var cpuTotals = parseCpuTotals(segments.cpu);
    if (cpuTotals === null) {
        failures.push("cpu");
    } else {
        var cpu = computeCpuPercent(next.cpuUsedTotal, next.cpuOverallTotal, cpuTotals);
        next.cpuUsedTotal = cpuTotals.used;
        next.cpuOverallTotal = cpuTotals.total;
        if (cpu !== null)
            next.cpuPercent = cpu;
    }

    var memory = parseMemInfo(segments.meminfo);
    if (memory === null) {
        failures.push("memory");
    } else {
        next.ramUsedGiB = memory.ramUsedGiB;
        next.ramPercent = memory.ramPercent;
    }

    next.available = true;
    next.lastError = failures.length > 0 ? ("failed to parse " + failures.join(", ")) : "";
    return next;
}

function reduceDiskSnapshot(previous, text, exitCode) {
    var next = copyState(previous);
    if ((exitCode || 0) !== 0)
        return next;
    var disk = parseDiskPercent(text);
    if (disk === null)
        next.lastError = "failed to parse disk";
    else
        next.diskPercent = disk;
    return next;
}

// Static host metadata is retained independently per field: a missing NixOS
// generation symlink (or any other absent key) leaves the last valid value
// in place rather than clearing it.
function reduceMetadataSnapshot(previous, text, exitCode) {
    if ((exitCode || 0) !== 0)
        return copyState(previous);
    var next = copyState(previous);
    var values = fields(text);
    if (values.host)
        next.hostName = values.host;
    if (values.kernel)
        next.kernel = values.kernel;
    if (values.uptime)
        next.uptime = formatUptime(values.uptime);
    if (values.gen)
        next.nixGeneration = values.gen;
    next.lastError = "";
    return next;
}
