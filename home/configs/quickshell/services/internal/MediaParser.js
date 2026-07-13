.pragma library

function finiteNumber(value, fallback) {
    const number = Number(value);
    return Number.isFinite(number) ? number : fallback;
}

function parseSnapshot(text, exitCode) {
    if (exitCode !== undefined && exitCode !== 0)
        return null;

    let raw;
    try {
        raw = JSON.parse(text);
    } catch (error) {
        return null;
    }

    const required = ["record", "status", "title", "artist", "album", "artUrl", "position", "length", "shuffle", "loop", "volume", "volumeSupported"];
    if (!raw || typeof raw !== "object" || raw.record !== true)
        return null;
    for (const key of required) {
        if (!Object.prototype.hasOwnProperty.call(raw, key))
            return null;
    }

    const status = raw.status === "Playing" || raw.status === "Paused" || raw.status === "Stopped" ? raw.status : "Stopped";
    const position = Math.max(0, finiteNumber(raw.position, 0));
    const length = Math.max(0, finiteNumber(raw.length, 0)) / 1000000;
    const volume = Math.max(0, Math.min(1, finiteNumber(raw.volume, 0)));
    const volumeSupported = raw.volumeSupported === true;

    return {
        available: true,
        playing: status === "Playing",
        status: status,
        title: String(raw.title),
        artist: String(raw.artist),
        album: String(raw.album),
        artUrl: String(raw.artUrl),
        positionSeconds: position,
        lengthSeconds: length,
        shuffleEnabled: String(raw.shuffle).toLowerCase() === "on",
        loopMode: raw.loop === "Track" || raw.loop === "Playlist" ? raw.loop : "None",
        playerVolume: volume,
        volumeIsPlayer: volumeSupported
    };
}

function volumeRoute(volumeIsPlayer, audioAvailable) {
    if (volumeIsPlayer)
        return "player";
    return audioAvailable ? "system" : "none";
}
