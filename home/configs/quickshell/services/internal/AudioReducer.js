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

function formatNodeLabel(rawName, description, nickname) {
    const raw = String(nickname || description || rawName || "").trim();
    if (!raw)
        return "Audio device";
    return raw
        .replace(/^Raptor Lake[-A-Za-z0-9/ ]*cAVS\s+/i, "")
        .replace(/^Alder Lake[-A-Za-z0-9/ ]*cAVS\s+/i, "")
        .replace(/\s+\(V4L2\)$/i, "")
        .trim() || raw;
}

function classifyOutputKind(rawName, iconName) {
    const name = String(rawName || "").toLowerCase();
    const icon = String(iconName || "").toLowerCase();
    if (name.indexOf("bluez_output.") === 0 || icon.indexOf("bluetooth") !== -1)
        return "bluetooth";
    if (name.indexOf("hdmi") !== -1 || name.indexOf("displayport") !== -1 || icon.indexOf("video-display") !== -1)
        return "hdmi";
    return "speaker";
}

function buildDeviceList(rawDevices, activeName) {
    const filtered = (rawDevices || []).filter(function (d) {
        if (!d || !d.name)
            return false;
        if (d.name === "bedroom-rtp-out" || d.name === "input.laptop-rtp-mirror")
            return false;
        return true;
    }).map(function (d) {
        const kind = classifyOutputKind(d.name, d.iconName);
        return {
            id: String(d.id || d.name),
            name: String(d.name),
            label: formatNodeLabel(d.name, d.description, d.nickname),
            kind: kind,
            bluetooth: kind === "bluetooth",
            active: d.name === activeName
        };
    });
    filtered.sort(function (a, b) {
        if (a.active !== b.active)
            return a.active ? -1 : 1;
        if (a.bluetooth !== b.bluetooth)
            return a.bluetooth ? -1 : 1;
        return a.label.localeCompare(b.label);
    });
    return filtered;
}

function detectPrivacyAndRtp(nodes, links) {
    const nodeByName = {};
    let hasRtpNode = false;
    for (let i = 0; i < (nodes || []).length; i++) {
        const n = nodes[i];
        if (!n || !n.name)
            continue;
        nodeByName[n.name] = n;
        if (n.name === "bedroom-rtp-out" || n.name === "input.laptop-rtp-mirror")
            hasRtpNode = true;
    }

    let micCapture = false;
    let cameraCapture = false;
    let screenCapture = false;
    let rtpLinked = false;

    for (let j = 0; j < (links || []).length; j++) {
        const link = links[j];
        if (!link || !link.source || !link.target)
            continue;
        const src = nodeByName[link.source];
        const dst = nodeByName[link.target];
        if (!src || !dst)
            continue;

        if (dst.name === "input.laptop-rtp-mirror" || dst.name === "bedroom-rtp-out" || src.name === "input.laptop-rtp-mirror")
            rtpLinked = true;

        const srcClass = String(src.mediaClass || "");
        const dstClass = String(dst.mediaClass || "");
        if (srcClass === "Audio/Source") {
            if (dst.captureSink === true || dst.bluezLoopback === true)
                continue;
            if (dst.name === "Peak detect" || dst.name === "cava")
                continue;
            if (dst.isStream === true || dstClass.indexOf("Stream/Input/Audio") === 0)
                micCapture = true;
        } else if (srcClass === "Video/Source") {
            const isCam = src.mediaRole === "Camera"
                || String(src.name).indexOf("v4l2_input.") === 0
                || String(src.name).indexOf("libcamera_input.") === 0;
            if (isCam)
                cameraCapture = true;
            else
                screenCapture = true;
        }
    }

    const tags = [];
    if (screenCapture)
        tags.push("screen");
    if (cameraCapture)
        tags.push("cam");
    if (micCapture)
        tags.push("mic");

    return {
        micCaptureActive: micCapture,
        cameraCaptureActive: cameraCapture,
        screenCaptureActive: screenCapture,
        privacySummary: tags.join(" · "),
        rtpMirrorActive: hasRtpNode && rtpLinked
    };
}
