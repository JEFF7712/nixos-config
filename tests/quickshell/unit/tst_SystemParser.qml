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
            cpuFirst: cpuLine(),
            cpuSecond: cpuLine({
                user: 1050,
                system: 220,
                idle: 8930
            }),
            meminfo: "MemTotal:        1048576 kB\n" + "MemFree:          200000 kB\n" + "MemAvailable:     324288 kB\n",
            disk: "Filesystem 1024-blocks Used Available Capacity Mounted on\n" + "/dev/sda1  1000000  400000  600000      40% /\n"
        };
        for (const key in overrides || {})
            parts[key] = overrides[key];
        return parts.cpuFirst + "\n" + SystemParser.MARK_CPU2 + "\n" + parts.cpuSecond + "\n" + SystemParser.MARK_MEM + "\n" + parts.meminfo + "\n" + SystemParser.MARK_DISK + "\n" + parts.disk;
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

    // "first CPU sample" behavior: only one reading is available (a second
    // sample never arrived), so the delta cannot be computed yet.
    function test_firstCpuSampleWithoutSecondReadingIsIncomplete() {
        compare(SystemParser.computeCpuPercent(cpuLine(), ""), null);
        compare(SystemParser.computeCpuPercent("", cpuLine()), null);
    }

    function test_validDeltaComputesPercent() {
        const percent = SystemParser.computeCpuPercent(cpuLine({
            user: 1000,
            system: 200,
            idle: 8800
        }), cpuLine({
            user: 1050,
            system: 220,
            idle: 8930
        }));
        // used delta = (1050+220)-(1000+200) = 70; total delta = (1050+0+220+8930)-(1000+0+200+8800) = 200
        compare(percent, 35);
    }

    function test_zeroOrNegativeTotalDeltaYieldsZeroNotError() {
        compare(SystemParser.computeCpuPercent(cpuLine(), cpuLine()), 0);
        compare(SystemParser.computeCpuPercent(cpuLine({
            user: 2000
        }), cpuLine({
            user: 1000
        })), 0);
    }

    function test_malformedProcStatReturnsNull() {
        compare(SystemParser.parseCpuTotals("not /proc/stat at all\n"), null);
        compare(SystemParser.parseCpuTotals("cpu  notanumber 0 0 0\n"), null);
        compare(SystemParser.computeCpuPercent("garbage", cpuLine()), null);
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
        const previous = SystemParser.reduceMetricsSnapshot(SystemParser.initialState(), metricsText(), 0);
        verify(previous.available);
        compare(previous.cpuPercent, 35);

        const malformedCpu = SystemParser.reduceMetricsSnapshot(previous, metricsText({
            cpuFirst: "not /proc/stat\n"
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

    function test_reduceMetricsSnapshotPreservesDiskOnDfFailure() {
        const previous = SystemParser.reduceMetricsSnapshot(SystemParser.initialState(), metricsText(), 0);
        const failedDisk = SystemParser.reduceMetricsSnapshot(previous, metricsText({
            disk: "df: /: No such file or directory\n"
        }), 0);
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
