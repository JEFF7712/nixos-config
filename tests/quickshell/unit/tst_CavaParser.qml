import QtQuick
import QtTest
import "../../../home/configs/quickshell/services/internal/CavaParser.js" as CavaParser

TestCase {
    name: "CavaParser"

    function test_emptyAndNonnumericFieldsAreZero() {
        compare(CavaParser.parseFrame("1;;wat;4"), [1, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0]);
    }

    function test_clampsPadsAndTruncatesToTwelveBars() {
        compare(CavaParser.parseFrame("-4;20;101"), [0, 20, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
        compare(CavaParser.parseFrame("1;2;3;4;5;6;7;8;9;10;11;12"), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
        compare(CavaParser.parseFrame("1;2;3;4;5;6;7;8;9;10;11;12;13"), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
    }

    function test_partialChunksAndCrLfProduceOnlyCompleteRecords() {
        const first = CavaParser.consume("", "1;2;3\r");
        compare(first.frames, []);
        compare(first.buffer, "1;2;3\r");

        const second = CavaParser.consume(first.buffer, "\n4;5\n");
        compare(second.frames, [[1, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0], [4, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]);
        compare(second.buffer, "");
    }

    function test_multipleRecordsKeepTrailingPartialRecord() {
        const result = CavaParser.consume("", "1\n2;3\n4;");
        compare(result.frames, [[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]);
        compare(result.buffer, "4;");
    }

    function test_clearReturnsTypedListCompatibleEmptyValues() {
        compare(CavaParser.clear(), []);
    }
}
