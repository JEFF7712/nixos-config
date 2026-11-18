import QtQuick
import QtTest
import "../../../home/configs/quickshell/services/internal/AudioReducer.js" as AudioReducer

TestCase {
    name: "AudioReducer"

    readonly property var initial: ({
            available: false,
            volumePercent: 25,
            muted: true
        })

    function observation(overrides) {
        const value = {
            backendReady: true,
            targetPresent: true,
            targetReady: true,
            controlsPresent: true,
            volume: 0.425,
            muted: false
        };
        Object.assign(value, overrides || {});
        return value;
    }

    function test_roundsAndClampsPercent() {
        compare(AudioReducer.reduce(initial, observation({
            volume: 0.425
        })).volumePercent, 43);
        compare(AudioReducer.reduce(initial, observation({
            volume: -0.2
        })).volumePercent, 0);
        compare(AudioReducer.reduce(initial, observation({
            volume: 1.2
        })).volumePercent, 100);
    }

    function test_readsMuteAndReadyTarget() {
        const state = AudioReducer.reduce(initial, observation({
            volume: 0.6,
            muted: true
        }));
        verify(state.available);
        compare(state.volumePercent, 60);
        verify(state.muted);
    }

    function test_unavailableInputsRetainLastValidState_data() {
        return [
            {
                tag: "backend-not-ready",
                overrides: {
                    backendReady: false
                }
            },
            {
                tag: "null-target",
                overrides: {
                    targetPresent: false
                }
            },
            {
                tag: "unready-target",
                overrides: {
                    targetReady: false
                }
            },
            {
                tag: "missing-controls",
                overrides: {
                    controlsPresent: false
                }
            },
            {
                tag: "invalid-volume-nan",
                overrides: {
                    volume: NaN
                }
            },
            {
                tag: "invalid-volume-infinity",
                overrides: {
                    volume: Infinity
                }
            }
        ];
    }

    function test_unavailableInputsRetainLastValidState(data) {
        const state = AudioReducer.reduce(initial, observation(data.overrides));
        verify(!state.available);
        compare(state.volumePercent, 25);
        verify(state.muted);
    }

    function test_recoversAfterUnavailableTarget() {
        const unavailable = AudioReducer.reduce(initial, observation({
            targetPresent: false
        }));
        const recovered = AudioReducer.reduce(unavailable, observation({
            volume: 0.81,
            muted: false
        }));
        verify(recovered.available);
        compare(recovered.volumePercent, 81);
        verify(!recovered.muted);
    }

    function test_formatNodeLabelStripsHardwarePrefixes() {
        compare(AudioReducer.formatNodeLabel("alsa_output.speaker", "Raptor Lake-P/U/H cAVS Speaker", ""), "Speaker");
        compare(AudioReducer.formatNodeLabel("v4l2_input.cam", "Logitech Webcam C925e (V4L2)", ""), "Logitech Webcam C925e");
        compare(AudioReducer.formatNodeLabel("bluez_output.1", "WH-1000XM4", ""), "WH-1000XM4");
    }

    function test_buildDeviceListFiltersInternalRtpAndSortsActiveFirst() {
        const list = AudioReducer.buildDeviceList([
            {
                id: 1,
                name: "bedroom-rtp-out",
                description: "RTP",
                nickname: "",
                iconName: ""
            },
            {
                id: 2,
                name: "alsa_output.hdmi",
                description: "HDMI 1",
                nickname: "",
                iconName: "video-display"
            },
            {
                id: 3,
                name: "bluez_output.bose",
                description: "Bose QC",
                nickname: "",
                iconName: ""
            },
            {
                id: 4,
                name: "alsa_output.speaker",
                description: "Speaker",
                nickname: "",
                iconName: ""
            }
        ], "alsa_output.speaker");
        compare(list.length, 3);
        compare(list[0].name, "alsa_output.speaker");
        verify(list[0].active);
        compare(list[1].name, "bluez_output.bose");
        verify(list[1].bluetooth);
        compare(list[2].kind, "hdmi");
    }

    function test_detectPrivacyIgnoresCavaMonitorAndDetectsMicCamScreenAndRtp() {
        const nodes = [
            {
                name: "bluez_output.bose",
                mediaClass: "Audio/Sink",
                mediaRole: "",
                isStream: false,
                captureSink: false,
                bluezLoopback: false
            },
            {
                name: "cava",
                mediaClass: "Stream/Input/Audio",
                mediaRole: "",
                isStream: true,
                captureSink: true,
                bluezLoopback: false
            },
            {
                name: "alsa_input.mic",
                mediaClass: "Audio/Source",
                mediaRole: "",
                isStream: false,
                captureSink: false,
                bluezLoopback: false
            },
            {
                name: "discord_capture",
                mediaClass: "Stream/Input/Audio",
                mediaRole: "",
                isStream: true,
                captureSink: false,
                bluezLoopback: false
            },
            {
                name: "v4l2_input.cam0",
                mediaClass: "Video/Source",
                mediaRole: "Camera",
                isStream: false,
                captureSink: false,
                bluezLoopback: false
            },
            {
                name: "niri-screencast",
                mediaClass: "Video/Source",
                mediaRole: "Screen",
                isStream: false,
                captureSink: false,
                bluezLoopback: false
            },
            {
                name: "browser_video",
                mediaClass: "Stream/Input/Video",
                mediaRole: "",
                isStream: true,
                captureSink: false,
                bluezLoopback: false
            },
            {
                name: "input.laptop-rtp-mirror",
                mediaClass: "Stream/Input/Audio",
                mediaRole: "",
                isStream: true,
                captureSink: true,
                bluezLoopback: false
            }
        ];
        const idle = AudioReducer.detectPrivacyAndRtp(nodes, [
            {
                source: "bluez_output.bose",
                target: "cava"
            }
        ]);
        verify(!idle.micCaptureActive);
        verify(!idle.cameraCaptureActive);
        verify(!idle.screenCaptureActive);
        verify(!idle.rtpMirrorActive);

        const live = AudioReducer.detectPrivacyAndRtp(nodes, [
            {
                source: "alsa_input.mic",
                target: "discord_capture"
            },
            {
                source: "v4l2_input.cam0",
                target: "browser_video"
            },
            {
                source: "niri-screencast",
                target: "browser_video"
            },
            {
                source: "bluez_output.bose",
                target: "input.laptop-rtp-mirror"
            }
        ]);
        verify(live.micCaptureActive);
        verify(live.cameraCaptureActive);
        verify(live.screenCaptureActive);
        verify(live.rtpMirrorActive);
        compare(live.privacySummary, "screen · cam · mic");
    }
}
