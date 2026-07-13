.pragma library

function clampPercent(percent) {
    return Math.max(0, Math.min(100, Math.round(percent)));
}

function reduce(previous, observation) {
    const valid = observation.backendReady
        && observation.targetPresent
        && observation.targetReady
        && observation.controlsPresent
        && typeof observation.volume === "number"
        && isFinite(observation.volume);

    if (!valid) {
        return {
            available: false,
            volumePercent: previous.volumePercent,
            muted: previous.muted
        };
    }

    return {
        available: true,
        volumePercent: clampPercent(observation.volume * 100),
        muted: Boolean(observation.muted)
    };
}
