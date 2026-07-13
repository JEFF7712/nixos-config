.pragma library

// Split markers embedded in the metrics probe's stdout. They separate the
// two /proc/stat samples (taken 200ms apart, matching the previous Topbar
// composite poll's delta window) from the /proc/meminfo and `df` segments.
var MARK_CPU2 = "###QS-CPU2###";
var MARK_MEM = "###QS-MEM###";
var MARK_DISK = "###QS-DISK###";

// Single subprocess invocation: it owns the 200ms delta window internally,
// so every dynamic-metrics poll is self-contained (no cross-poll CPU state).
var METRICS_COMMAND = "cat /proc/stat 2>/dev/null; " + "printf '\\n%s\\n' '" + MARK_CPU2 + "'; " + "sleep 0.2; " + "cat /proc/stat 2>/dev/null; " + "printf '\\n%s\\n' '" + MARK_MEM + "'; " + "cat /proc/meminfo 2>/dev/null; " + "printf '\\n%s\\n' '" + MARK_DISK + "'; " + "df -P / 2>&1";

// Static host metadata: hostname, kernel, uptime, and NixOS generation.
// Mirrors the previous SystemPopup fetchProc adapter, minus the memory
// percentage (now derived from the metrics probe's /proc/meminfo read).
var METADATA_COMMAND = "echo \"host|$(hostnamectl hostname 2>/dev/null || hostname)\"; " + "echo \"kernel|$(uname -r)\"; " + "echo \"uptime|$(uptime -p 2>/dev/null | sed 's/^up //')\"; " + "g=$(readlink /nix/var/nix/profiles/system 2>/dev/null | grep -o '[0-9]*' | head -1); " + "[ -n \"$g\" ] && echo \"gen|$g\" || true";

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
        lastError: ""
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
        lastError: base.lastError || ""
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

// Returns null when either sample cannot be parsed (including when only the
// first sample of a delta window is available), so callers preserve the
// last valid cpuPercent instead of fabricating a value.
function computeCpuPercent(firstText, secondText) {
    var first = parseCpuTotals(firstText);
    var second = parseCpuTotals(secondText);
    if (!first || !second)
        return null;
    var deltaTotal = second.total - first.total;
    if (deltaTotal <= 0)
        return 0;
    var deltaUsed = second.used - first.used;
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
    var cpuSplit = raw.indexOf(MARK_CPU2);
    var memSplit = raw.indexOf(MARK_MEM);
    var diskSplit = raw.indexOf(MARK_DISK);
    if (cpuSplit < 0 || memSplit < 0 || diskSplit < 0 || memSplit < cpuSplit || diskSplit < memSplit)
        return null;
    return {
        cpuFirst: raw.substring(0, cpuSplit),
        cpuSecond: raw.substring(cpuSplit + MARK_CPU2.length, memSplit),
        meminfo: raw.substring(memSplit + MARK_MEM.length, diskSplit),
        disk: raw.substring(diskSplit + MARK_DISK.length)
    };
}

// Publishes only complete samples: cpu/memory/disk are retained
// independently whenever their own segment fails to parse, and the whole
// snapshot is left untouched on a nonzero exit or unparseable output.
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

    var cpu = computeCpuPercent(segments.cpuFirst, segments.cpuSecond);
    if (cpu === null)
        failures.push("cpu");
    else
        next.cpuPercent = cpu;

    var memory = parseMemInfo(segments.meminfo);
    if (memory === null) {
        failures.push("memory");
    } else {
        next.ramUsedGiB = memory.ramUsedGiB;
        next.ramPercent = memory.ramPercent;
    }

    var disk = parseDiskPercent(segments.disk);
    if (disk === null)
        failures.push("disk");
    else
        next.diskPercent = disk;

    next.available = true;
    next.lastError = failures.length > 0 ? ("failed to parse " + failures.join(", ")) : "";
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
        next.uptime = values.uptime;
    if (values.gen)
        next.nixGeneration = values.gen;
    next.lastError = "";
    return next;
}
