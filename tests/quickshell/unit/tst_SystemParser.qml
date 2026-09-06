import QtQuick
import QtTest
import "../../../home/configs/quickshell/services/internal/SystemParser.js" as SystemParser

TestCase {
    name: "SystemParser"

    function cpuLine(overrides) {
        const fields = {
            user: 1000,
            nice: 0,
            system: 200,
            idle: 8800
        };
        for (const key in overrides || {})
            fields[key] = overrides[key];
        return "cpu  " + fields.user + " " + fields.nice + " " + fields.system + " " + fields.idle + " 0 0 0 0 0 0\n" + "cpu0 " + fields.user + " " + fields.nice + " " + fields.system + " " + fields.idle + " 0 0 0 0 0 0\n";
    }

    function metricsText(overrides) {
        const parts = {
            cpu: cpuLine(),
            meminfo: "MemTotal:        1048576 kB\n" + "MemFree:          200000 kB\n" + "MemAvailable:     324288 kB\n"
        };
        for (const key in overrides || {})
            parts[key] = overrides[key];
        return parts.cpu + "\n" + SystemParser.MARK_MEM + "\n" + parts.meminfo;
    }

    function metadataText(overrides) {
        const values = {
            host: "myhost",
            kernel: "6.6.6-nixos",
            uptime: "3 days",
            gen: "42"
        };
        for (const key in overrides || {})
            values[key] = overrides[key];
        let text = "";
        for (const key in values) {
            if (values[key] !== undefined)
                text += key + "|" + values[key] + "\n";
        }
        return text;
    }

    function test_firstCpuSampleIsRetainedForNextPoll() {
        const first = SystemParser.reduceMetricsSnapshot(SystemParser.initialState(), metricsText(), 0);
        compare(first.cpuPercent, 0);
        compare(first.cpuUsedTotal, 1200);
        compare(first.cpuOverallTotal, 10000);
    }

    function test_consecutivePollDeltaComputesPercent() {
        const first = SystemParser.reduceMetricsSnapshot(SystemParser.initialState(), metricsText(), 0);
        const second = SystemParser.reduceMetricsSnapshot(first, metricsText({
            cpu: cpuLine({
                user: 1050,
                system: 220,
                idle: 8930
            })
        }), 0);
        // used delta = (1050+220)-(1000+200) = 70; total delta = (1050+0+220+8930)-(1000+0+200+8800) = 200
        compare(second.cpuPercent, 35);
    }

    function test_resetCountersStartANewBaseline() {
        const previous = SystemParser.reduceMetricsSnapshot(SystemParser.initialState(), metricsText(), 0);
        const reset = SystemParser.reduceMetricsSnapshot(previous, metricsText({
            cpu: cpuLine({
                user: 10,
                system: 2,
                idle: 88
            })
        }), 0);
        compare(reset.cpuPercent, previous.cpuPercent);
        compare(reset.cpuUsedTotal, 12);
        compare(reset.cpuOverallTotal, 100);
    }

    function test_malformedProcStatReturnsNull() {
        compare(SystemParser.parseCpuTotals("not /proc/stat at all\n"), null);
        compare(SystemParser.parseCpuTotals("cpu  notanumber 0 0 0\n"), null);
        compare(SystemParser.computeCpuPercent(null, null, SystemParser.parseCpuTotals(cpuLine())), null);
    }

    function test_missingMemoryFieldsReturnsNull() {
        compare(SystemParser.parseMemInfo("MemTotal:   1048576 kB\n"), null);
        compare(SystemParser.parseMemInfo("MemAvailable: 324288 kB\n"), null);
        compare(SystemParser.parseMemInfo(""), null);
    }

    function test_memInfoComputesUsedGiBAndPercent() {
        const parsed = SystemParser.parseMemInfo("MemTotal:        1048576 kB\n" + "MemAvailable:      262144 kB\n");
        compare(parsed.ramPercent, 75);
        compare(parsed.ramUsedGiB, (1048576 - 262144) / 1048576);
    }

    function test_diskFailureReturnsNull() {
        compare(SystemParser.parseDiskPercent(""), null);
        compare(SystemParser.parseDiskPercent("df: /: No such file or directory\n"), null);
        compare(SystemParser.parseDiskPercent("Filesystem 1024-blocks Used Available Capacity Mounted on\n"), null);
    }

    function test_diskPercentParsesCapacityColumn() {
        compare(SystemParser.parseDiskPercent("Filesystem 1024-blocks Used Available Capacity Mounted on\n" + "/dev/sda1  1000000  400000  600000      42% /\n"), 42);
    }

    function test_reduceMetricsSnapshotPreservesLastValidPerFieldOnMalformedStat() {
        const first = SystemParser.reduceMetricsSnapshot(SystemParser.initialState(), metricsText(), 0);
        const previous = SystemParser.reduceMetricsSnapshot(first, metricsText({
            cpu: cpuLine({
                user: 1050,
                system: 220,
                idle: 8930
            })
        }), 0);
        verify(previous.available);
        compare(previous.cpuPercent, 35);

        const malformedCpu = SystemParser.reduceMetricsSnapshot(previous, metricsText({
            cpu: "not /proc/stat\n"
        }), 0);
        compare(malformedCpu.cpuPercent, previous.cpuPercent);
        compare(malformedCpu.ramPercent, previous.ramPercent);
        compare(malformedCpu.diskPercent, previous.diskPercent);
        verify(malformedCpu.available);
        compare(malformedCpu.lastError, "failed to parse cpu");
    }

    function test_reduceMetricsSnapshotPreservesRamOnMissingMemoryFields() {
        const previous = SystemParser.reduceMetricsSnapshot(SystemParser.initialState(), metricsText(), 0);
        const malformedMem = SystemParser.reduceMetricsSnapshot(previous, metricsText({
            meminfo: "MemTotal:   1048576 kB\n"
        }), 0);
        compare(malformedMem.ramUsedGiB, previous.ramUsedGiB);
        compare(malformedMem.ramPercent, previous.ramPercent);
        compare(malformedMem.cpuPercent, previous.cpuPercent);
        compare(malformedMem.diskPercent, previous.diskPercent);
        compare(malformedMem.lastError, "failed to parse memory");
    }

    function test_reduceDiskSnapshotPreservesDiskOnDfFailure() {
        const previous = SystemParser.reduceDiskSnapshot(SystemParser.initialState(), "Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/sda1 100 40 60 40% /\n", 0);
        const failedDisk = SystemParser.reduceDiskSnapshot(previous, "df: /: No such file or directory\n", 0);
        compare(failedDisk.diskPercent, previous.diskPercent);
        compare(failedDisk.cpuPercent, previous.cpuPercent);
        compare(failedDisk.ramPercent, previous.ramPercent);
        compare(failedDisk.lastError, "failed to parse disk");
    }

    function test_reduceMetricsSnapshotPreservesEverythingOnNonzeroExit() {
        const previous = SystemParser.reduceMetricsSnapshot(SystemParser.initialState(), metricsText(), 0);
        compare(SystemParser.reduceMetricsSnapshot(previous, metricsText(), 1), previous);
    }

    function test_reduceMetricsSnapshotPreservesEverythingOnUnparseableOutput() {
        const previous = SystemParser.reduceMetricsSnapshot(SystemParser.initialState(), metricsText(), 0);
        const noMarkers = SystemParser.reduceMetricsSnapshot(previous, "not a metrics snapshot at all", 0);
        compare(noMarkers.cpuPercent, previous.cpuPercent);
        compare(noMarkers.ramPercent, previous.ramPercent);
        compare(noMarkers.diskPercent, previous.diskPercent);
        compare(noMarkers.available, previous.available);
        compare(noMarkers.lastError, "failed to parse metrics snapshot");
    }

    function test_formatUptimeFromSeconds() {
        compare(SystemParser.formatUptime(""), "");
        compare(SystemParser.formatUptime("0"), "0 minutes");
        compare(SystemParser.formatUptime("59"), "0 minutes");
        compare(SystemParser.formatUptime("60"), "1 minute");
        compare(SystemParser.formatUptime("120"), "2 minutes");
        compare(SystemParser.formatUptime("3600"), "1 hour");
        compare(SystemParser.formatUptime("3660"), "1 hour, 1 minute");
        compare(SystemParser.formatUptime("86400"), "1 day");
        compare(SystemParser.formatUptime("93780"), "1 day, 2 hours, 3 minutes");
        compare(SystemParser.formatUptime("259200"), "3 days");
        compare(SystemParser.formatUptime("3 days"), "3 days");
    }

    function test_reduceMetadataSnapshotFormatsUptimeSeconds() {
        const reduced = SystemParser.reduceMetadataSnapshot(SystemParser.initialState(), metadataText({
            uptime: "93780"
        }), 0);
        compare(reduced.uptime, "1 day, 2 hours, 3 minutes");
    }

    function test_reduceMetadataSnapshotMissingGenerationSymlinkPreservesLastValid() {
        const previous = SystemParser.reduceMetadataSnapshot(SystemParser.initialState(), metadataText(), 0);
        compare(previous.nixGeneration, "42");

        const missingGen = SystemParser.reduceMetadataSnapshot(previous, metadataText({
            gen: undefined
        }), 0);
        compare(missingGen.nixGeneration, "42");
        compare(missingGen.hostName, "myhost");
        compare(missingGen.kernel, "6.6.6-nixos");
        compare(missingGen.uptime, "3 days");
    }

    function test_reduceMetadataSnapshotCompleteHostMetadata() {
        const reduced = SystemParser.reduceMetadataSnapshot(SystemParser.initialState(), metadataText(), 0);
        compare(reduced.hostName, "myhost");
        compare(reduced.kernel, "6.6.6-nixos");
        compare(reduced.uptime, "3 days");
        compare(reduced.nixGeneration, "42");
        compare(reduced.lastError, "");
    }

    function test_reduceMetadataSnapshotPreservesEverythingOnNonzeroExit() {
        const previous = SystemParser.reduceMetadataSnapshot(SystemParser.initialState(), metadataText(), 0);
        compare(SystemParser.reduceMetadataSnapshot(previous, metadataText({
            host: "otherhost"
        }), 1), previous);
    }
}
