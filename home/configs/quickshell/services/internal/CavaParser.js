.pragma library

var barCount = 12;

function parseValue(field) {
    const trimmed = field.trim();
    if (trimmed === "")
        return 0;
    const value = Number(trimmed);
    if (!Number.isFinite(value))
        return 0;
    return Math.max(0, Math.min(100, Math.trunc(value)));
}

function parseFrame(record) {
    const fields = record.split(";");
    const values = [];
    for (let index = 0; index < barCount; index++)
        values.push(index < fields.length ? parseValue(fields[index]) : 0);
    return values;
}

function consume(buffer, chunk) {
    const records = (buffer + chunk).split("\n");
    const trailing = records.pop();
    const frames = [];
    for (const record of records)
        frames.push(parseFrame(record.endsWith("\r") ? record.slice(0, -1) : record));
    return {buffer: trailing, frames: frames};
}

function clear() {
    return [];
}
